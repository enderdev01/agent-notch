import AppKit

/// Quiet, throttled cues so the notch never nags: a soft system sound per agent when it finishes
/// and a short tick when it needs approval. Honors the menu bar sound toggle.
@MainActor
enum Sounds {
    private static let minGap: TimeInterval = 2
    private static var lastPlayed = Date.distantPast

    static func finished(_ agent: AgentKind) {
        switch agent {
        case .claude: play("Hero")
        case .codex: play("Glass")
        case .gentle: play("Ping")
        }
    }

    static func approvalNeeded() { play("Tink", enabled: Preferences.approvalSoundEnabled) }

    /// A burst of events (several agents finishing together) plays one sound, not a chord.
    private static func play(_ name: String, enabled: Bool = Preferences.soundEnabled) {
        guard enabled, Date().timeIntervalSince(lastPlayed) >= minGap,
              let sound = NSSound(named: name) else { return }
        lastPlayed = Date()
        sound.volume = Preferences.soundVolume
        sound.play()
    }
}
