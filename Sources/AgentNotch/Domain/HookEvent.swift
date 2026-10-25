import Foundation

/// Normalized lifecycle event, Claude-hook style, produced from any agent's payload.
struct HookEvent: Sendable {
    let agent: AgentKind
    let name: String
    let sessionId: String
    let cwd: String?
    let toolName: String?
    let toolSummary: String?
    let prompt: String?
    let message: String?
    let lastAssistantMessage: String?
    /// Task list carried by the tool input, when the tool is a todo/plan update.
    var steps: [Step]? = nil
    /// Terminal context sent by the bridge as headers (not part of the hook JSON).
    var terminal: TerminalRef? = nil
}
