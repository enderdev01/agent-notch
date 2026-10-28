import Foundation
import Testing
@testable import AgentNotch

@MainActor
struct ClaudeTaskProgressTests {
    private let desktopPlan = "mcp__desktop__update_plan"
    private let initial: [String: Any] = ["items": [
        ["content": "First", "status": "in_progress"],
        ["content": "Second", "status": "pending"],
        ["content": "Third", "status": "pending"]
    ]]

    @discardableResult
    private func ingest(_ store: SessionStore, agent: AgentKind = .claude,
                        event: String = "PreToolUse", tool: String,
                        input: [String: Any]) throws -> HookEvent {
        let data = try JSONSerialization.data(withJSONObject: [
            "hook_event_name": event, "session_id": "progress",
            "cwd": "/test/project", "tool_name": tool, "tool_input": input
        ])
        let decoded = try #require(HookPayloadDecoder.decode(agent: agent, data: data))
        store.ingest(event: decoded)
        return decoded
    }

    @Test func desktopAdvanceRunsOnlyOnPreToolUse() throws {
        let store = SessionStore()
        try ingest(store, tool: desktopPlan, input: initial)
        let edit = try ingest(store, tool: desktopPlan, input: ["advance": true])
        #expect(edit.toolSummary == nil)
        let expected = [Step(title: "First", state: .done),
                        Step(title: "Second", state: .running),
                        Step(title: "Third", state: .pending)]
        #expect(store.sessions["claude:progress"]?.steps == expected)
        #expect(store.sessions["claude:progress"]?.status == .runningTool(desktopPlan))
        try ingest(store, event: "PostToolUse", tool: desktopPlan, input: ["advance": true])
        #expect(store.sessions["claude:progress"]?.steps == expected)
        #expect(store.sessions["claude:progress"]?.status == .thinking)
        #expect(store.sessions["claude:progress"]?.lastMessage == nil)
        #expect(store.sessions["claude:progress"]?.cwd == "/test/project")
        #expect(store.sessions.count == 1)
    }

    @Test func desktopDoneAndStartUseOneBasedPositions() throws {
        let store = SessionStore()
        try ingest(store, tool: desktopPlan, input: initial)
        let edit = try ingest(store, tool: desktopPlan, input: ["done": [1, 2], "start": 3])
        #expect(edit.toolSummary == nil)
        let expected = [Step(title: "First", state: .done),
                        Step(title: "Second", state: .done),
                        Step(title: "Third", state: .running)]
        #expect(store.sessions["claude:progress"]?.steps == expected)
        try ingest(store, event: "PostToolUse", tool: desktopPlan, input: ["done": [1, 2], "start": 3])
        #expect(store.sessions["claude:progress"]?.steps == expected)
        #expect(store.sessions["claude:progress"]?.lastMessage == nil)
    }

    @Test func desktopWrapUpCompletesTheExistingList() throws {
        let store = SessionStore()
        try ingest(store, tool: desktopPlan, input: initial)
        let edit = try ingest(store, tool: "mcp__desktop__wrap_up", input: [:])
        #expect(edit.toolSummary == nil)
        let expected = ["First", "Second", "Third"].map { Step(title: $0, state: .done) }
        #expect(store.sessions["claude:progress"]?.steps == expected)
        try ingest(store, event: "PostToolUse", tool: "mcp__desktop__wrap_up", input: [:])
        #expect(store.sessions["claude:progress"]?.steps == expected)
        #expect(store.sessions["claude:progress"]?.status == .thinking)
    }

    @Test func fullTaskListsStillReplaceSteps() throws {
        let store = SessionStore()
        try ingest(store, tool: desktopPlan, input: initial)
        #expect(store.sessions["claude:progress"]?.steps == [
            Step(title: "First", state: .running), Step(title: "Second", state: .pending),
            Step(title: "Third", state: .pending)])
        let todo: [String: Any] = ["todos": [
            ["content": "Build", "activeForm": "Building", "status": "in_progress"]]]
        let claude = try ingest(store, tool: "TodoWrite", input: todo)
        #expect(claude.toolSummary == nil)
        #expect(store.sessions["claude:progress"]?.steps == [Step(title: "Building", state: .running)])
        let plan: [String: Any] = ["plan": [["step": "Verify", "status": "completed"]]]
        let codex = try ingest(store, agent: .codex, tool: "update_plan", input: plan)
        #expect(codex.toolSummary == nil)
        #expect(store.sessions["codex:progress"]?.steps == [Step(title: "Verify", state: .done)])
        #expect(store.sessions["claude:progress"]?.steps == [Step(title: "Building", state: .running)])
        try ingest(store, event: "PostToolUse", tool: "TodoWrite", input: [
            "todos": [["content": "Build", "status": "completed"]]])
        #expect(store.sessions["claude:progress"]?.steps == [Step(title: "Build", state: .done)])
    }

    @Test func gentlePhaseReportsRemainBookkeeping() throws {
        let store = SessionStore()
        let report = try ingest(store, agent: .gentle, tool: "gentle_odd_phase", input: ["phase": "checking"])
        #expect(report.toolSummary == nil)
        #expect(store.sessions["gentle:progress"]?.phase == .checking)
        #expect(store.sessions["gentle:progress"]?.status == .thinking)
        #expect(store.sessions["gentle:progress"]?.lastMessage == nil)
        try ingest(store, agent: .gentle, tool: "gentle_odd_phase", input: ["phase": "clear"])
        #expect(store.sessions["gentle:progress"]?.phase == nil)
        #expect(store.sessions["gentle:progress"]?.status == .thinking)
    }
}
