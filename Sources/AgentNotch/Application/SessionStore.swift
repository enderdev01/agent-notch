import Foundation

@MainActor
final class SessionStore: ObservableObject {
    @Published private(set) var sessions: [String: AgentSession] = [:]
    @Published private(set) var approvals: [ApprovalRequest] = []
    /// Set briefly after a session finishes; drives the "done" glow and checkmark.
    @Published private(set) var doneFlash: AgentKind?
    /// When true, every approval immediately falls back to the agent's terminal prompt.
    @Published var approvalsPaused = false
    /// Short-lived look at the last reply (or error), shown under the collapsed notch.
    @Published private(set) var peek: Peek?
    /// Today's per-agent totals; persisted and reset when the day changes (read through `todayStats`).
    @Published private(set) var stats: [AgentKind: DayStats] = [:]

    /// Called when a session reaches Stop (used for the optional sound).
    var onSessionFinished: ((AgentSession) -> Void)?
    /// How long a finished session keeps the "Your turn" mark when its reply asked the user something
    /// (0 turns the mark off). Set from the user's preference by the app.
    var askRetention: TimeInterval = 5 * 60

    /// Called when an agent starts waiting for an Allow/Deny decision.
    var onApprovalRequested: ((ApprovalRequest) -> Void)?
    /// Called when an agent asks the user a question through its question tool.
    var onQuestionAsked: ((AgentSession) -> Void)?

    static let approvalTimeout: Duration = .seconds(110)
    static let finishedRetention: TimeInterval = 30 * 60
    /// How long a failed turn keeps the sad mascot before the session goes back to idle.
    static let failedRetention: TimeInterval = 60
    static let staleRetention: TimeInterval = 6 * 60 * 60
    /// A "working" session that stays silent this long is treated as idle: Claude sends no event when
    /// interrupted (e.g. Esc; Codex sends `Interrupt`), so without this the mascot would keep working
    /// until staleRetention.
    static let workingTimeout: TimeInterval = {
        ProcessInfo.processInfo.environment["AGENT_NOTCH_WORKING_TIMEOUT"].flatMap(TimeInterval.init) ?? 180
    }()

    private var continuations: [UUID: CheckedContinuation<Decision, Never>] = [:]
    private var timeouts: [UUID: Task<Void, Never>] = [:]
    private var flashToken = 0
    private var peekToken = 0
    private var statsDay = ""
    private var pruneTimer: Timer?

    init() {
        loadStats()
        pruneTimer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.prune() }
        }
    }

    deinit { pruneTimer?.invalidate() }

    // MARK: Events

    func ingest(event: HookEvent) {
        let key = Self.key(event.agent, event.sessionId)
        var session = sessions[key] ?? AgentSession(
            id: key, agent: event.agent, cwd: event.cwd, status: .idle,
            lastMessage: nil, updatedAt: Date())
        if let cwd = event.cwd, !cwd.isEmpty { session.cwd = cwd }
        if let terminal = event.terminal { session.terminal = terminal }
        session.updatedAt = Date()

        switch event.name {
        case "SessionStart":
            session.status = .idle
        case "UserPromptSubmit":
            session.status = .thinking
            session.asksUser = false
            session.phase = nil
            session.turnStartedAt = Date()
            // A finished list belongs to the previous request; an unfinished one carries over.
            if session.steps.allSatisfy({ $0.state == .done }) { session.steps = [] }
            if let p = event.prompt, !p.isEmpty { session.lastMessage = p; session.prompt = p }
        case "PreToolUse":
            if let asked = event.question {
                // Claude is blocked on the user: show a question that needs them, not a running tool.
                // The permission request for this tool arrives right after and repeats this event; ignore the repeat.
                if session.status == .done, session.asksUser, session.lastMessage == asked.text { return }
                session.status = .done
                session.asksUser = askRetention > 0
                session.lastMessage = asked.text
                session.reply = asked.reply
                sessions[key] = session
                showPeek(Peek(agent: session.agent, text: asked.summary, isError: false, asksUser: session.asksUser))
                onQuestionAsked?(session)
                return
            }
            if let report = event.phase {
                // A phase report is bookkeeping, not a tool the user should see running; "clear" or an unknown phase drops it.
                session.phase = OddPhase(rawValue: report)
                session.status = .thinking
                session.asksUser = false
                if session.turnStartedAt == nil { session.turnStartedAt = Date() }
                break
            }
            session.status = .runningTool(event.toolName ?? "tool")
            session.asksUser = false
            if session.turnStartedAt == nil { session.turnStartedAt = Date() }
            if let s = event.toolSummary, !s.isEmpty { session.lastMessage = s }
            if let steps = event.steps { session.steps = steps }
        case "PostToolUse":
            if session.status != .waitingApproval { session.status = .thinking }
            if let steps = event.steps { session.steps = steps }
        case "Notification":
            // While the user owes an answer, keep the question as the row's line instead of "Claude needs your permission…".
            let waiting = session.asksUser && session.status == .done
            if let m = event.message, !m.isEmpty, !waiting { session.lastMessage = m }
        case "Interrupt":
            // Codex reports Esc/interrupts; Claude does not, so `workingTimeout` still covers it.
            if session.status.isWorking { session.status = .idle; session.turnStartedAt = nil }
            session.phase = nil
        case "StopFailure":
            session.status = .failed
            session.phase = nil
            let text = ReplyText.error(event.message)
            session.lastMessage = text
            // Keep the raw code next to the friendly text in the detail view.
            session.reply = ReplyText.isKnownError(event.message) ? "\(text) (\(event.message ?? ""))" : text
            record(session, failed: true)
            session.turnStartedAt = nil
            showPeek(Peek(agent: session.agent, text: text, isError: true))
        case "Stop":
            // A failed turn may be followed by a plain Stop; keep the failure visible until the next prompt.
            if session.status == .failed { return }
            session.status = .done
            session.phase = nil
            var snippet: ReplyText.Snippet?
            if let m = event.lastAssistantMessage, !m.isEmpty {
                session.lastMessage = m
                session.reply = m
                snippet = ReplyText.snippet(m)
            }
            session.asksUser = askRetention > 0 && (snippet?.asksUser ?? false)
            record(session, failed: false)
            session.turnStartedAt = nil
            sessions[key] = session
            flashDone(session)
            if let snippet, !snippet.text.isEmpty {
                showPeek(Peek(agent: session.agent, text: snippet.text, isError: false, asksUser: snippet.asksUser))
            }
            return
        default:
            return
        }
        sessions[key] = session
    }

    // MARK: Approvals

    func requestApproval(_ request: ApprovalRequest) async -> Decision {
        if approvalsPaused { return .terminal }
        approvals.append(request)
        setStatus(for: request, to: .waitingApproval)
        onApprovalRequested?(request)
        return await withCheckedContinuation { continuation in
            continuations[request.id] = continuation
            timeouts[request.id] = Task { [weak self] in
                try? await Task.sleep(for: Self.approvalTimeout)
                guard !Task.isCancelled else { return }
                self?.resolve(id: request.id, decision: .terminal)
            }
        }
    }

    func resolve(id: UUID, decision: Decision) {
        guard let continuation = continuations.removeValue(forKey: id) else { return }
        timeouts.removeValue(forKey: id)?.cancel()
        if let index = approvals.firstIndex(where: { $0.id == id }) {
            let request = approvals.remove(at: index)
            if sessions[Self.key(request.agent, request.sessionId)]?.status == .waitingApproval {
                setStatus(for: request, to: .thinking)
            }
        }
        continuation.resume(returning: decision)
    }

    /// Resolve every pending approval (used on pause and by the debug route).
    func resolveAll(decision: Decision) {
        for request in approvals { resolve(id: request.id, decision: decision) }
    }

    // MARK: Housekeeping

    func prune(now: Date = Date()) {
        var kept: [String: AgentSession] = [:]
        for (key, var session) in sessions {
            let age = now.timeIntervalSince(session.updatedAt)
            if session.status.isWorking, age > Self.workingTimeout { session.status = .idle; session.turnStartedAt = nil }
            if session.status == .failed, age > Self.failedRetention { session.status = .idle }
            if session.asksUser, age > askRetention { session.asksUser = false }
            let keep: Bool
            switch session.status {
            case .done: keep = age <= Self.finishedRetention
            case .waitingApproval: keep = true
            default: keep = age <= Self.staleRetention
            }
            if keep { kept[key] = session }
        }
        if kept != sessions { sessions = kept }
    }

    // MARK: Peek and daily stats

    static let peekDuration: Duration = .seconds(5)

    /// Today's totals for an agent, or nil when it has not finished a turn today.
    func todayStats(_ agent: AgentKind) -> DayStats? {
        statsDay == Self.dayKey() ? stats[agent] : nil
    }

    private func showPeek(_ new: Peek) {
        peekToken += 1
        let token = peekToken
        peek = new
        Task { [weak self] in
            try? await Task.sleep(for: Self.peekDuration)
            guard let self, self.peekToken == token else { return }
            self.peek = nil
        }
    }

    private func record(_ session: AgentSession, failed: Bool) {
        if statsDay != Self.dayKey() { statsDay = Self.dayKey(); stats = [:] }
        var entry = stats[session.agent] ?? DayStats()
        if failed { entry.failed += 1 } else { entry.done += 1 }
        entry.seconds += min(session.turnStartedAt.map { Date().timeIntervalSince($0) } ?? 0, 6 * 3600)
        stats[session.agent] = entry
        saveStats()
    }

    private static func dayKey(_ date: Date = Date()) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    private struct StoredStats: Codable {
        var day: String
        var stats: [String: DayStats]
    }
    private static let statsKey = "dayStats"

    private func loadStats() {
        guard let data = UserDefaults.standard.data(forKey: Self.statsKey),
              let stored = try? JSONDecoder().decode(StoredStats.self, from: data),
              stored.day == Self.dayKey() else { return }
        statsDay = stored.day
        stats = Dictionary(uniqueKeysWithValues: stored.stats.compactMap { key, value in
            AgentKind(rawValue: key).map { ($0, value) }
        })
    }

    private func saveStats() {
        let stored = StoredStats(
            day: statsDay,
            stats: Dictionary(uniqueKeysWithValues: stats.map { ($0.key.rawValue, $0.value) }))
        UserDefaults.standard.set(try? JSONEncoder().encode(stored), forKey: Self.statsKey)
    }

    // MARK: Private

    private static func key(_ agent: AgentKind, _ sessionId: String) -> String {
        "\(agent.rawValue):\(sessionId)"
    }

    private func setStatus(for request: ApprovalRequest, to status: SessionStatus) {
        let key = Self.key(request.agent, request.sessionId)
        var session = sessions[key] ?? AgentSession(
            id: key, agent: request.agent, cwd: nil, status: status,
            lastMessage: nil, updatedAt: Date())
        session.status = status
        session.updatedAt = Date()
        sessions[key] = session
    }

    private func flashDone(_ session: AgentSession) {
        onSessionFinished?(session)
        flashToken += 1
        let token = flashToken
        doneFlash = session.agent
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.8))
            guard let self, self.flashToken == token else { return }
            self.doneFlash = nil
        }
    }
}
