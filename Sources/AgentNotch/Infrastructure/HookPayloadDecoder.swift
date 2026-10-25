import Foundation

/// Turns raw hook JSON (Claude/Codex/Pi-extension) into a normalized `HookEvent`.
enum HookPayloadDecoder {
    static func decode(agent: AgentKind, data: Data) -> HookEvent? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        let parsed = steps(toolInput: object["tool_input"])
        return HookEvent(
            agent: agent,
            name: object["hook_event_name"] as? String ?? "",
            sessionId: object["session_id"] as? String ?? "default",
            cwd: object["cwd"] as? String,
            toolName: object["tool_name"] as? String,
            // A task-list update is shown as steps, not as raw JSON in the row.
            toolSummary: parsed == nil ? summarize(toolInput: object["tool_input"]) : nil,
            prompt: object["prompt"] as? String,
            message: (object["message"] as? String) ?? (object["error"] as? String),
            lastAssistantMessage: object["last_assistant_message"] as? String,
            steps: parsed)
    }

    /// Claude `TodoWrite` sends `todos` [{content, activeForm, status}]; Codex `update_plan` sends `plan` [{step, status}].
    static func steps(toolInput: Any?) -> [Step]? {
        guard let dict = toolInput as? [String: Any] else { return nil }
        guard let items = (dict["todos"] ?? dict["plan"]) as? [[String: Any]] else { return nil }
        return items.compactMap { item in
            let state: Step.State
            switch item["status"] as? String {
            case "completed": state = .done
            case "in_progress": state = .running
            default: state = .pending
            }
            let running = state == .running ? item["activeForm"] as? String : nil
            guard let title = running ?? item["content"] as? String ?? item["step"] as? String, !title.isEmpty else { return nil }
            return Step(title: title, state: state)
        }
    }

    /// Human-readable one-liner for a tool input: command, path, or compact JSON.
    static func summarize(toolInput: Any?) -> String? {
        if let text = toolInput as? String { return clip(text) }
        guard let dict = toolInput as? [String: Any], !dict.isEmpty else { return nil }
        for key in ["command", "file_path", "path", "url", "pattern", "query"] {
            if let value = dict[key] as? String, !value.isEmpty { return clip(value) }
        }
        guard let data = try? JSONSerialization.data(withJSONObject: dict, options: [.sortedKeys]),
              let json = String(data: data, encoding: .utf8) else { return nil }
        return clip(json)
    }

    private static func clip(_ text: String, limit: Int = 600) -> String {
        text.count > limit ? String(text.prefix(limit)) + "…" : text
    }
}
