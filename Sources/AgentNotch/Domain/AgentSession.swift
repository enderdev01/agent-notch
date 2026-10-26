import Foundation

enum SessionStatus: Equatable, Sendable {
    case idle
    case thinking
    case runningTool(String)
    case waitingApproval
    case done
    /// The turn ended with an error (e.g. rate limit); expires back to idle after a minute.
    case failed

    /// True while the agent is doing something on the user's behalf (or needs the user's attention).
    var isActive: Bool {
        switch self {
        case .thinking, .runningTool, .waitingApproval, .failed: return true
        case .idle, .done: return false
        }
    }

    /// True while the agent is actually working (not blocked on the user).
    var isWorking: Bool {
        switch self {
        case .thinking, .runningTool: return true
        default: return false
        }
    }

    var label: String {
        switch self {
        case .idle: return L("Idle")
        case .thinking: return L("Thinking")
        case .runningTool(let name): return L("Running %@", name)
        case .waitingApproval: return L("Waiting for approval")
        case .done: return L("Done")
        case .failed: return L("Failed")
        }
    }
}

/// One item of the agent's own task list (Claude `TodoWrite`, Codex `update_plan`).
struct Step: Equatable, Sendable {
    enum State: Equatable, Sendable { case pending, running, done }
    let title: String
    let state: State
}

/// Where an agent runs: the terminal app and, when known, its tty (used to pick the tab).
struct TerminalRef: Equatable, Sendable {
    let bundleId: String
    let tty: String?
}

struct AgentSession: Identifiable, Equatable, Sendable {
    let id: String
    let agent: AgentKind
    var cwd: String?
    var status: SessionStatus
    var lastMessage: String?
    var updatedAt: Date
    /// Start of the turn in progress (nil when no turn is running); drives the timer and daily stats.
    var turnStartedAt: Date?
    /// Full text of the latest prompt and of the latest reply (or error), for the hover detail.
    var prompt: String?
    var reply: String?
    /// The last reply ended by asking the user for something ("Your turn"); cleared by the next activity.
    var asksUser = false
    /// The agent's current task list, in order; empty when it has none.
    var steps: [Step] = []
    /// Terminal the agent runs in, from the hook bridge; nil when unknown (click falls back to the folder).
    var terminal: TerminalRef?

    var projectName: String { displayProjectName(from: cwd) }
}

/// A short look at what an agent just said (or why it failed), shown briefly under the collapsed notch.
struct Peek: Equatable, Sendable {
    let agent: AgentKind
    let text: String
    let isError: Bool
    /// The reply ends by asking the user for something, so the peek is highlighted.
    var asksUser = false
}

/// What one agent got done today.
struct DayStats: Codable, Equatable, Sendable {
    var done = 0
    var failed = 0
    var seconds: Double = 0
}

/// Last path component of a working directory, or a placeholder.
func displayProjectName(from cwd: String?) -> String {
    guard let cwd, !cwd.isEmpty else { return L("Unknown project") }
    let name = (cwd as NSString).lastPathComponent
    return name.isEmpty ? cwd : name
}
