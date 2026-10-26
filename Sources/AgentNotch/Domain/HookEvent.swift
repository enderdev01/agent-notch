import Foundation

/// A question the agent put to the user through its own question tool (first question only; the rest are counted).
struct AskedQuestion: Equatable, Sendable {
    let text: String
    let options: [String]
    let more: Int

    /// One line for the peek: the question, plus how many more were asked with it.
    var summary: String { more > 0 ? "\(text) \(L("+%ld more", more))" : text }

    /// Question and its options, for the hover card.
    var reply: String { ([text] + options.map { "• \($0)" }).joined(separator: "\n") }
}

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
    /// The question Claude is asking the user, when the tool is `AskUserQuestion`.
    var question: AskedQuestion? = nil
    /// Terminal context sent by the bridge as headers (not part of the hook JSON).
    var terminal: TerminalRef? = nil
}
