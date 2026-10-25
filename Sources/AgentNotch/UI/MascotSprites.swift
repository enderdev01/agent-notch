import AppKit

/// Loads the pixel-art mascot for an agent. Looks in the app bundle first, then next to the sources
/// (so `make run` / `swift run` work without bundling).
@MainActor
enum MascotSprites {
    private static var cache: [String: NSImage] = [:]

    /// A variant (`<agent>-<variant>.png`: sleep, work, alert, done) falls back to the base sprite when missing.
    static func image(for agent: AgentKind, variant: String? = nil) -> NSImage? {
        if let variant, let image = load("\(agent.rawValue)-\(variant)") { return image }
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
