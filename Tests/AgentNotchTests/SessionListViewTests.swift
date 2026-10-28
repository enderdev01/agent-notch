import Foundation
import SwiftUI
import Testing
@testable import AgentNotch

@MainActor
struct SessionListViewTests {
    private func session(_ id: String, agent: AgentKind, at time: TimeInterval) -> AgentSession {
        AgentSession(id: id, agent: agent, cwd: nil, status: .done,
                     lastMessage: nil, updatedAt: Date(timeIntervalSince1970: time))
    }

    private func view(_ sessions: [AgentSession]) -> SessionListView {
        SessionListView(sessions: sessions, reduceMotion: true, stats: { _ in nil },
                        hovered: .constant(nil), contentHeight: .constant(0))
    }

    @Test(arguments: [AgentKind.claude, .codex, .gentle])
    func mostRecentlyUsedAgentComesFirst(latest: AgentKind) {
        let sessions = AgentKind.allCases.map { agent in
            session(agent.rawValue, agent: agent, at: agent == latest ? 20 : 10)
        }
        #expect(view(sessions).groups.first?.0 == latest)
    }

    @Test func sessionsStayGroupedAndNewestFirst() {
        let sessions = [
            session("claude-old", agent: .claude, at: 1),
            session("gentle-new", agent: .gentle, at: 4),
            session("claude-new", agent: .claude, at: 3),
            session("gentle-old", agent: .gentle, at: 2)
        ]
        let groups = view(sessions).groups
        #expect(groups.map(\.0) == [.gentle, .claude])
        #expect(groups.map { $0.1.map(\.id) } == [
            ["gentle-new", "gentle-old"], ["claude-new", "claude-old"]
        ])
        #expect(view([]).groups.isEmpty)
    }
}
