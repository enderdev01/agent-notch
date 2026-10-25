import Foundation

struct ApprovalRequest: Identifiable, Equatable, Sendable {
    let id: UUID
    let agent: AgentKind
    let sessionId: String
    let project: String
    let toolName: String
    let summary: String
    let createdAt: Date

    init(id: UUID = UUID(), agent: AgentKind, sessionId: String, project: String,
         toolName: String, summary: String, createdAt: Date = Date()) {
        self.id = id
        self.agent = agent
        self.sessionId = sessionId
        self.project = project
        self.toolName = toolName
        self.summary = summary
        self.createdAt = createdAt
    }
}

/// Outcome of an approval request. `terminal` means "let the agent ask in its own terminal".
enum Decision: String, Sendable {
    case allow
    case deny
    case terminal
}
