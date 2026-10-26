import Foundation

/// User preferences, backed by UserDefaults. Every change posts `Preferences.changed` so the UI refreshes live.
enum Preferences {
    static let changed = Notification.Name("AgentNotchPreferencesChanged")

    /// Sound when an agent finishes (key kept from the first version).
    static var soundEnabled: Bool {
        get { bool("soundOnDone", true) }
        set { save(newValue, "soundOnDone") }
    }
    static var approvalSoundEnabled: Bool {
        get { bool("soundOnApproval", true) }
        set { save(newValue, "soundOnApproval") }
    }
    /// 0...1, applied on top of the system volume.
    static var soundVolume: Float {
        get { Float(number("soundVolume", 0.3)) }
        set { save(Double(newValue), "soundVolume") }
    }
    /// Seconds of inactivity until the idle mascot is fully asleep (it starts getting drowsy after a third).
    static var sleepAfter: TimeInterval {
        get { number("sleepAfter", 60) }
        set { save(newValue, "sleepAfter") }
    }
    /// Seconds the "Your turn" mark stays after a reply that asks something; 0 turns it off.
    static var yourTurnFor: TimeInterval {
        get { number("yourTurnFor", 5 * 60) }
        set { save(newValue, "yourTurnFor") }
    }
    /// When false the collapsed notch shows nothing while all agents are idle.
    static var showIdleMascot: Bool {
        get { bool("showIdleMascot", true) }
        set { save(newValue, "showIdleMascot") }
    }

    /// True once the first-launch "Connect your agents?" offer was shown (it is offered only once).
    static var connectPromptShown: Bool {
        get { bool("connectPromptShown", false) }
        set { save(newValue, "connectPromptShown") }
    }

    private static func bool(_ key: String, _ fallback: Bool) -> Bool {
        UserDefaults.standard.object(forKey: key) as? Bool ?? fallback
    }

    private static func number(_ key: String, _ fallback: Double) -> Double {
        UserDefaults.standard.object(forKey: key) as? Double ?? fallback
    }

    private static func save(_ value: Any, _ key: String) {
        UserDefaults.standard.set(value, forKey: key)
        NotificationCenter.default.post(name: changed, object: nil)
    }
}
