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

/// Incremental task-list update from the Claude desktop app: `update_plan` with `advance` / `done` / `start` (1-based), or `wrap_up`.
struct StepEdit: Equatable, Sendable {
    var advance = false
    var done: [Int] = []
    var start: Int? = nil
    var finishAll = false

    func apply(to steps: [Step]) -> [Step] {
        var steps = steps
        func set(_ i: Int, _ state: Step.State) {
            if steps.indices.contains(i) { steps[i] = Step(title: steps[i].title, state: state) }
        }
        if finishAll { steps.indices.forEach { set($0, .done) }; return steps }
        if advance {
            if let running = steps.firstIndex(where: { $0.state == .running }) { set(running, .done) }
            if let next = steps.firstIndex(where: { $0.state == .pending }) { set(next, .running) }
        }
        done.forEach { set($0 - 1, .done) }
        if let start { set(start - 1, .running) }
        return steps
    }
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
    /// Incremental change to the task list already shown (the desktop app's `update_plan` without `items`, or `wrap_up`).
    var stepEdit: StepEdit? = nil
    /// The question Claude is asking the user, when the tool is `AskUserQuestion`.
    var question: AskedQuestion? = nil
    /// ODD phase Gentle Shell reported through `gentle_odd_phase` (or "clear" to leave it).
    var phase: String? = nil
    /// Terminal context sent by the bridge as headers (not part of the hook JSON).
    var terminal: TerminalRef? = nil
}
