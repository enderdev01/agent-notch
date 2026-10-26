import AppKit

/// Loads the pixel-art mascot for an agent. Looks in the app bundle first, then next to the sources
/// (so `make run` / `swift run` work without bundling).
@MainActor
enum MascotSprites {
    private static var cache: [String: NSImage] = [:]

    /// A variant (`<agent>-<variant>.png`: sleep, work, alert, done, work-check...) falls back to its
    /// parent (`work-check` -> `work`), then to the base sprite, when missing.
    static func image(for agent: AgentKind, variant: String? = nil) -> NSImage? {
        var name = variant
        while let current = name {
            if let image = load("\(agent.rawValue)-\(current)") { return image }
            name = current.contains("-") ? current.split(separator: "-").dropLast().joined(separator: "-") : nil
        }
        return load(agent.rawValue)
    }

    private static func load(_ name: String) -> NSImage? {
        if let cached = cache[name] { return cached }
        let devPath = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Resources/Mascots/\(name).png")
        let url = Bundle.main.url(forResource: name, withExtension: "png")
            ?? (FileManager.default.fileExists(atPath: devPath.path) ? devPath : nil)
        guard let url, let image = NSImage(contentsOf: url) else { return nil }
        cache[name] = image
        return image
    }
}
