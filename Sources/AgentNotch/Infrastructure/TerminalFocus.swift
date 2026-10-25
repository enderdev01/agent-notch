import AppKit

/// Brings the terminal an agent runs in to the front; Terminal.app and iTerm2 also get the right tab selected.
enum TerminalFocus {
    /// Returns false when the terminal is not running (or unknown), so the caller can fall back.
    @MainActor @discardableResult
    static func focus(_ terminal: TerminalRef) -> Bool {
        guard !NSRunningApplication.runningApplications(withBundleIdentifier: terminal.bundleId).isEmpty,
              let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: terminal.bundleId) else { return false }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.openApplication(at: url, configuration: configuration)
        // Tab selection needs the Automation permission; when it is denied the app is still in front.
        if let tty = terminal.tty, tty.range(of: #"^/dev/tty[a-z0-9]+$"#, options: .regularExpression) != nil,
           let source = script(bundleId: terminal.bundleId, tty: tty) {
            // Out of process so the permission prompt (or a slow terminal) never blocks the notch.
            let osascript = Process()
            osascript.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            osascript.arguments = ["-e", source]
            osascript.standardOutput = FileHandle.nullDevice
            osascript.standardError = FileHandle.nullDevice
            try? osascript.run()
        }
        return true
    }

    private static func script(bundleId: String, tty: String) -> String? {
        switch bundleId {
        case "com.apple.Terminal":
            return """
            tell application "Terminal"
              repeat with w in windows
                repeat with t in tabs of w
                  if tty of t is "\(tty)" then
                    set selected of t to true
                    set index of w to 1
                    return
                  end if
                end repeat
              end repeat
            end tell
            """
        case "com.googlecode.iterm2":
            return """
            tell application "iTerm2"
              repeat with w in windows
                repeat with t in tabs of w
                  repeat with s in sessions of t
                    if tty of s is "\(tty)" then
                      tell w to select
                      tell t to select
                      tell s to select
                      return
                    end if
                  end repeat
                end repeat
              end repeat
            end tell
            """
        default:
            return nil
        }
    }
}
