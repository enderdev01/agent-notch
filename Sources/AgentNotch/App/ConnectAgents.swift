import AppKit

/// Runs the installer bundled inside the app (`Resources/scripts/install.sh`), so connecting Claude Code, Codex and Pi
/// needs no terminal, and reports what changed.
@MainActor
enum ConnectAgents {
    private static var home: String { ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory() }

    private static var installer: URL? {
        Bundle.main.resourceURL.map { $0.appendingPathComponent("scripts/install.sh") }
            .flatMap { FileManager.default.fileExists(atPath: $0.path) ? $0 : nil }
    }

    /// The bridge is the first thing the installer copies, so its presence means agents were connected before.
    private static var isConnected: Bool {
        FileManager.default.fileExists(atPath: home + "/.local/bin/agent-notch-hook")
    }

    /// One-time offer on first launch; the menu item stays available afterwards.
    static func promptIfNeeded() {
        guard installer != nil, !isConnected, !Preferences.connectPromptShown else { return }
        Preferences.connectPromptShown = true
        let alert = NSAlert()
        alert.messageText = L("Connect your agents?")
        alert.informativeText = L("Agent Notch needs a small hook in Claude Code, Codex and Pi to see what they are doing. This adds entries to their config files (backed up once as *.bak-agent-notch). You can do it later from the menu bar item.")
        alert.addButton(withTitle: L("Connect"))
        alert.addButton(withTitle: L("Not now"))
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn { run() }
    }

    static func run() {
        guard let script = installer else {
            show(title: L("Not available"), text: L("Connect agents needs the bundled app (make app)."), style: .warning)
            return
        }
        Task {
            let result = await Task.detached { execute(script) }.value
            report(result)
        }
    }

    private nonisolated static func execute(_ script: URL) -> (status: Int32, output: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [script.path]
        var env = ProcessInfo.processInfo.environment
        // A Finder-launched app has a minimal PATH; Homebrew's jq lives outside it.
        env["PATH"] = "/usr/bin:/bin:/opt/homebrew/bin:/usr/local/bin:" + (env["PATH"] ?? "")
        process.environment = env
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        do { try process.run() } catch { return (-1, error.localizedDescription) }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()  // read before waiting, or a full pipe would block the script
        process.waitUntilExit()
        return (process.terminationStatus, String(decoding: data, as: UTF8.self))
    }

    private static func report(_ result: (status: Int32, output: String)) {
        let output = result.output.replacingOccurrences(of: home, with: "~")
        guard result.status == 0 else {
            if output.contains("jq is required") {
                show(title: L("jq is required"),
                     text: L("Agent Notch needs jq to edit your agents' config files. macOS 15 and later include it; on macOS 14 install it with:\n\nbrew install jq\n\nThen choose Connect agents again."),
                     style: .warning)
            } else {
                show(title: L("Could not connect agents"), text: String(output.suffix(600)), style: .warning)
            }
            return
        }
        // The installer prints English status words; show them in the user's language.
        let labels = [("installed:", L("installed:")), ("updated:", L("updated:")), ("unchanged:", L("unchanged:"))]
        let changes = output.split(separator: "\n").compactMap { line -> String? in
            guard let (english, local) = labels.first(where: { line.hasPrefix($0.0) }) else { return nil }
            return local + String(line.dropFirst(english.count))
        }.joined(separator: "\n")
        show(title: L("Agents connected"),
             text: changes + "\n\n" + L("Restart any running Claude Code, Codex or Pi session. Codex may ask you to trust the new hooks."),
             style: .informational)
    }

    private static func show(title: String, text: String, style: NSAlert.Style) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = text
        alert.alertStyle = style
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }
}
