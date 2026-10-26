import SwiftUI

struct NotchRootView: View {
    @ObservedObject var store: SessionStore
    @ObservedObject var viewModel: NotchViewModel

    private var expanded: Bool { viewModel.hovering || !store.approvals.isEmpty }
    private var activeSessions: [AgentSession] { store.sessions.values.filter { $0.status.isActive } }
    private var activeAgents: [AgentKind] {
        AgentKind.allCases.filter { agent in activeSessions.contains { $0.agent == agent } }
    }
    private var workingAgents: [AgentKind] {
        AgentKind.allCases.filter { agent in
            store.sessions.values.contains { $0.agent == agent && $0.status.isWorking }
        }
    }
    /// True when nothing is happening: the ear shows one dimmed, breathing mascot instead of going dark.
    private var isIdle: Bool {
        activeAgents.isEmpty && store.doneFlash == nil && store.approvals.isEmpty && store.peek == nil
    }
    private var showsIdleMascot: Bool { Preferences.showIdleMascot }
    /// Start of the longest-running turn, for the timer in the right ear.
    private var longestTurnStart: Date? {
        store.sessions.values.filter { $0.status.isWorking }.compactMap(\.turnStartedAt).min()
    }
    /// Session whose task list is shown under the collapsed notch: the latest one still working through steps.
    private var stepSession: AgentSession? {
        store.sessions.values
            .filter { $0.status.isActive && $0.steps.contains { $0.state != .done } }
            .max { $0.updatedAt < $1.updatedAt }
    }
    /// Most recently used agent (Claude before any session exists).
    private var idleAgent: AgentKind {
        store.sessions.values.max { $0.updatedAt < $1.updatedAt }?.agent ?? .claude
    }

    /// Agents shown as mascots in the left ear: the active ones plus the one that just finished.
    private var earAgents: [AgentKind] {
        if isIdle { return showsIdleMascot ? [idleAgent] : [] }
        return AgentKind.allCases.filter {
            activeAgents.contains($0) || store.doneFlash == $0 || store.peek?.agent == $0
        }
    }
    private var mascotSize: CGFloat { max(16, min(viewModel.geometry.notchHeight - 8, 26)) }
    private var mascotOverlap: CGFloat { mascotSize * 0.4 }
    /// Full ears share one width so the notch cut-out stays centered. In idle only the left ear exists
    /// (smaller) and the whole shape shifts left, so it never covers menu bar icons right of the notch.
    private var leftEarWidth: CGFloat { isIdle ? (showsIdleMascot ? mascotSize + 18 : 0) : earWidth }
    private var rightEarWidth: CGFloat { isIdle ? 0 : earWidth }
    private var shiftX: CGFloat { expanded ? 0 : (rightEarWidth - leftEarWidth) / 2 }
    private var earWidth: CGFloat {
        let count = CGFloat(max(earAgents.count, 1))
        let mascots = mascotSize * count - mascotOverlap * (count - 1)
        return max(NotchLayout.earWidth, mascots + 12)
    }

    private var chin: CGFloat { !expanded && !workingAgents.isEmpty ? 4 : 0 }

    /// The agent's last reply asked the user something and nothing has happened since ("Your turn").
    private func awaitsUser(_ agent: AgentKind) -> Bool {
        store.sessions.values.contains { $0.agent == agent && $0.status == .done && $0.asksUser }
    }

    private func mood(for agent: AgentKind) -> MascotMood {
        if store.approvals.contains(where: { $0.agent == agent }) { return .waiting }
        if store.sessions.values.contains(where: { $0.agent == agent && $0.status == .failed }) { return .error }
        if store.doneFlash == agent { return .done }
        let working = store.sessions.values.filter { $0.agent == agent && $0.status.isWorking }
        if !working.isEmpty { return .working(phase: working.compactMap(\.phase).first) }
        return .resting(store.sessions.values.filter { $0.agent == agent })
    }

    private var spring: Animation? {
        viewModel.reduceMotion ? nil : .spring(response: 0.42, dampingFraction: 0.78)
    }

    var body: some View {
        let notchW = viewModel.geometry.notchWidth
        let notchH = viewModel.geometry.notchHeight
        let top = NotchLayout.topRadius
        let bodyWidth = expanded
            ? NotchLayout.expandedWidth
            : notchW + leftEarWidth + rightEarWidth

        VStack(spacing: 0) {
            Group {
                if expanded { expandedBody(notchHeight: notchH) } else { collapsedBody(notchW: notchW, notchH: notchH) }
            }
            // The notch hardware hides anything inside its own height, so the accent line gets a chin below it.
            .padding(.bottom, chin)
            .frame(width: bodyWidth)
            .padding(.horizontal, top)
            .background(NotchShape(topRadius: top, bottomRadius: expanded ? 24 : 10).fill(.black))
            // Overlay on the animated shape (not a child of the content), so the line follows the spring and never detaches.
            .overlay(alignment: .bottom) {
                if !expanded, !workingAgents.isEmpty {
                    AccentLine(colors: workingAgents.map(\.color), reduceMotion: viewModel.reduceMotion)
                        .padding(.horizontal, 12 + top)
                        .padding(.bottom, 1)
                        .transition(.opacity)
                }
            }
            .overlay(doneGlow(expanded: expanded))
            .offset(x: shiftX)
            .onGeometryChange(for: CGSize.self, of: { $0.size }) { viewModel.shapeSize = $0 }
            .animation(spring, value: expanded)
            .animation(spring, value: isIdle)
            .onChange(of: shiftX, initial: true) { _, x in viewModel.shapeOffsetX = x }
            .animation(spring, value: chin)
            .animation(spring, value: store.approvals.count)
            .animation(spring, value: store.peek)
            .animation(spring, value: stepSession?.steps)
            .animation(spring, value: viewModel.hoveredSession)
            .animation(spring, value: store.sessions.count)
            Spacer(minLength: 0)
        }
        .frame(width: NotchLayout.panelSize.width, height: NotchLayout.panelSize.height, alignment: .top)
        .environment(\.colorScheme, .dark)
    }

    // MARK: Collapsed

    private func collapsedBody(notchW: CGFloat, notchH: CGFloat) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                HStack(spacing: -mascotOverlap) {
                    ForEach(earAgents, id: \.self) { agent in
                        MascotView(agent: agent, mood: mood(for: agent), size: mascotSize,
                                   reduceMotion: viewModel.reduceMotion)
                            .opacity(isIdle ? 0.75 : 1)
                            .overlay(alignment: .topTrailing) {
                                if awaitsUser(agent) {
                                    Circle().fill(Color(hex: 0xFFB020)).frame(width: 7, height: 7).offset(x: 2, y: 1)
                                }
                            }
                    }
                }
                .frame(width: leftEarWidth)

                Color.clear.frame(width: notchW)

                // ZStack + clear: an empty ear must still take its width, or the whole row shifts off-center.
                ZStack { Color.clear; rightEar }.frame(width: rightEarWidth)
            }
            .frame(height: notchH)

            // The hardware notch hides its own height, so the peek (or the step strip) lives below it.
            if store.peek == nil, let session = stepSession {
                StepStrip(steps: session.steps, color: session.agent.color, reduceMotion: viewModel.reduceMotion)
                    .transition(.opacity)
            }
            if let peek = store.peek {
                Text(peek.text)
                    .font(.system(size: 11))
                    .foregroundStyle(peek.isError ? Color(hex: 0xFF8A8D) : peek.asksUser ? Color(hex: 0xFFB020) : .white.opacity(0.85))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 9)
                    .transition(.opacity)
            }
        }
    }

    @ViewBuilder private var rightEar: some View {
        if !store.approvals.isEmpty {
            Text("\(store.approvals.count)")
                .font(.system(size: 11, weight: .bold).monospacedDigit())
                .foregroundStyle(.black)
                .frame(minWidth: 16, minHeight: 16)
                .background(Circle().fill(Color(hex: 0xFFB020)))
        } else if store.sessions.values.contains(where: { $0.status == .failed }) {
            Image(systemName: "xmark")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color(hex: 0xE5484D))
        } else if let agent = store.doneFlash {
            Image(systemName: "checkmark")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(agent.color)
        } else if let start = longestTurnStart {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                Text(Formatting.clock(context.date.timeIntervalSince(start)))
                    .font(.system(size: 10, weight: .medium).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.55))
            }
        }
    }

    // MARK: Expanded

    private func expandedBody(notchHeight: CGFloat) -> some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: notchHeight + 4)
            Group {
                if let request = store.approvals.first {
                    ApprovalCard(request: request, index: 0, total: store.approvals.count,
                                 reduceMotion: viewModel.reduceMotion) { decision in
                        store.resolve(id: request.id, decision: decision)
                    }
                    .id(request.id)
                } else {
                    SessionListView(sessions: Array(store.sessions.values), reduceMotion: viewModel.reduceMotion,
                                    stats: store.todayStats, hovered: $viewModel.hoveredSession,
                                    contentHeight: $viewModel.listContentHeight)
                }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 16)
        }
    }

    // MARK: Done glow

    private func doneGlow(expanded: Bool) -> some View {
        let color = store.doneFlash?.color ?? .clear
        return NotchShape(topRadius: NotchLayout.topRadius, bottomRadius: expanded ? 24 : 10)
            .stroke(color, lineWidth: 2)
            .blur(radius: 5)
            .opacity(store.doneFlash == nil ? 0 : 0.95)
            .animation(viewModel.reduceMotion ? nil : .easeOut(duration: 0.4), value: store.doneFlash)
            .allowsHitTesting(false)
    }
}
