import AppKit
import SwiftUI

struct SessionListView: View {
    let sessions: [AgentSession]
    let reduceMotion: Bool
    /// Today's totals per agent (nil until the agent finishes a turn).
    let stats: (AgentKind) -> DayStats?
    /// Id of the row under the mouse; that row shows its full prompt and reply.
    @Binding var hovered: String?

    private var groups: [(AgentKind, [AgentSession])] {
        AgentKind.allCases.compactMap { agent in
            let items = sessions.filter { $0.agent == agent }.sorted { $0.updatedAt > $1.updatedAt }
            return items.isEmpty ? nil : (agent, items)
        }
    }

    /// Fixed height of the detail panel under the list; the list never resizes on hover, so rows stay under the pointer.
    private static let detailHeight: CGFloat = 212

    /// Real height of the list content, measured so the detail card sits right under the last row.
    @Binding var contentHeight: CGFloat

    private var listHeight: CGFloat {
        if contentHeight > 0 { return min(260, contentHeight) }
        // shortcut: first-frame estimate until the content is measured.
        let stepRows = sessions.reduce(0) { $0 + (StepList.rows(for: $1.steps)) }
        return min(260, CGFloat(groups.count) * 42 + CGFloat(sessions.count) * 54 + CGFloat(stepRows) * 17)
    }

    private func mood(for items: [AgentSession]) -> MascotMood {
        if items.contains(where: { $0.status == .waitingApproval }) { return .waiting }
        if items.contains(where: { $0.status == .failed }) { return .error }
        let working = items.filter { $0.status.isWorking }
        if !working.isEmpty { return .working(phase: working.compactMap(\.phase).first) }
        return .resting(items)
    }

    /// "Today · ✓ 12 · ✕ 1 · 1h 20m"
    private func summary(_ day: DayStats) -> String {
        var parts = [L("Today"), "✓ \(day.done)"]
        if day.failed > 0 { parts.append("✕ \(day.failed)") }
        parts.append(Formatting.duration(day.seconds))
        return parts.joined(separator: " · ")
    }

    private func summaryText(_ day: DayStats) -> some View {
        Text(summary(day))
            .font(.system(size: 10).monospacedDigit())
            .foregroundStyle(.white.opacity(0.45))
    }

    var body: some View {
        if sessions.isEmpty {
            VStack(spacing: 6) {
                Text(L("No active agents"))
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.5))
                ForEach(AgentKind.allCases.filter { stats($0) != nil }, id: \.self) { agent in
                    HStack {
                        Text(agent.displayName.uppercased()).tracking(0.6)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(agent.color)
                        Spacer()
                        if let day = stats(agent) { summaryText(day) }
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
        } else {
            VStack(alignment: .leading, spacing: 8) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(groups, id: \.0) { agent, items in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                MascotView(agent: agent, mood: mood(for: items), size: 28,
                                           reduceMotion: reduceMotion)
                                Text(agent.displayName.uppercased()).tracking(0.6)
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(agent.color)
                                Spacer()
                                if let day = stats(agent) { summaryText(day) }
                            }
                            ForEach(items) { session in
                                SessionRow(session: session, highlighted: hovered == session.id, reduceMotion: reduceMotion)
                                    .contentShape(Rectangle())
                                    // Sticky: leaving a row keeps it open until another row is entered or the notch
                                    // collapses, so the panel doesn't shrink under the pointer between rows.
                                    .onHover { inside in
                                        if inside { hovered = session.id }
                                    }
                                    .onTapGesture { Self.open(session) }
                            }
                        }
                    }
                }
                .onGeometryChange(for: CGFloat.self, of: { $0.size.height }) { contentHeight = $0 }
            }
            .frame(height: listHeight)
            if let session = sessions.first(where: { $0.id == hovered }) {
                SessionDetail(session: session)
                    .frame(height: Self.detailHeight, alignment: .top)
                    .transition(.opacity)
            }
            }
        }
    }

    /// Focuses the agent's terminal; sessions without terminal info (or whose terminal closed) open the folder.
    private static func open(_ session: AgentSession) {
        if let terminal = session.terminal, TerminalFocus.focus(terminal) { return }
        openFolder(of: session)
    }

    private static func openFolder(of session: AgentSession) {
        guard let cwd = session.cwd, FileManager.default.fileExists(atPath: cwd) else { return }
        NSWorkspace.shared.open(URL(fileURLWithPath: cwd))
    }
}

struct SessionRow: View {
    let session: AgentSession
    let highlighted: Bool
    let reduceMotion: Bool

    private var failed: Bool { session.status == .failed }
    private var yourTurn: Bool { session.status == .done && session.asksUser }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(session.agent.color.opacity(session.status.isActive ? 1 : 0.35))
                .frame(width: 7, height: 7)
                .padding(.top, 5)
            VStack(alignment: .leading, spacing: 1) {
                Text(session.projectName)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                statusLine
                if !session.steps.isEmpty {
                    StepList(steps: session.steps, color: session.agent.color, reduceMotion: reduceMotion)
                }
                if let message = session.lastMessage, !message.isEmpty {
                    Text(message)
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.38))
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            Text(session.updatedAt, style: .relative)
                .font(.system(size: 10).monospacedDigit())
                .foregroundStyle(.white.opacity(0.4))
        }
        .padding(.vertical, 2)
        .background(alignment: .leading) {
            // Tinted with the agent color and tied to the detail card below, so the link row -> detail reads at a glance.
            RoundedRectangle(cornerRadius: 6)
                .fill(session.agent.color.opacity(highlighted ? 0.16 : 0))
                .overlay(alignment: .leading) {
                    Capsule().fill(session.agent.color).frame(width: 2).padding(.vertical, 4).padding(.leading, 2)
                        .opacity(highlighted ? 1 : 0)
                }
                .padding(.horizontal, -6)
        }
    }

    /// "Thinking · 2:14" while a turn runs, just the status otherwise.
    @ViewBuilder private var statusLine: some View {
        if let start = session.turnStartedAt, session.status.isWorking {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                statusText("\(session.status.label) · \(Formatting.clock(context.date.timeIntervalSince(start)))")
            }
        } else {
            statusText(yourTurn ? L("Your turn") : session.status.label)
        }
    }

    private func statusText(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11))
            .foregroundStyle(failed ? Color(hex: 0xFF8A8D) : yourTurn ? Color(hex: 0xFFB020) : .white.opacity(0.6))
            .lineLimit(1)
    }

}

/// Prompt and reply of the hovered row, shown in a fixed panel under the list.
struct SessionDetail: View {
    let session: AgentSession

    private var failed: Bool { session.status == .failed }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Circle().fill(session.agent.color).frame(width: 7, height: 7)
                Text(session.projectName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }
            if let prompt = session.prompt, !prompt.isEmpty { block(L("YOU"), ReplyText.detail(prompt, limit: 120), lines: 2) }
            if let reply = session.reply, !reply.isEmpty {
                block(failed ? L("ERROR") : L("REPLY"), ReplyText.detail(reply, limit: 330), lines: 6,
                      tint: failed ? Color(hex: 0xFF8A8D) : .white.opacity(0.8))
            }
            if let cwd = session.cwd, !cwd.isEmpty {
                Text((cwd as NSString).abbreviatingWithTildeInPath)
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.3))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            HStack(spacing: 8) {
                if let reply = session.reply, !reply.isEmpty {
                    Button { Self.copy(reply) } label: {
                        Text(L("Copy reply"))
                            .font(.system(size: 10, weight: .medium))
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Capsule().fill(.white.opacity(0.12)))
                    }
                    .buttonStyle(.plain)
                }
                if session.cwd != nil {
                    Text(session.terminal == nil ? L("Click to open folder") : L("Click to open terminal"))
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.3))
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 10).fill(session.agent.color.opacity(0.10)))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(session.agent.color.opacity(0.35), lineWidth: 1))
    }

    private func block(_ title: String, _ text: AttributedString, lines: Int, tint: Color = .white.opacity(0.8)) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title).tracking(0.8)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.white.opacity(0.35))
            Text(text)
                .font(.system(size: 11))
                .foregroundStyle(tint)
                .lineLimit(lines)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private static func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}
