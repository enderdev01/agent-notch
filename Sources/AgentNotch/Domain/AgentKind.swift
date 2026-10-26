import Foundation

/// The coding agents Agent Notch can observe.
enum AgentKind: String, CaseIterable, Sendable, Codable {
    case claude
    case codex
    case gentle

    var displayName: String {
        switch self {
        case .claude: return "Claude Code"
        case .codex: return "Codex"
        case .gentle: return "Gentle Shell"
        }
    }

    /// SF Symbol name.
    var symbol: String {
        switch self {
        case .claude: return "sparkle"
        case .codex: return "terminal"
        case .gentle: return "camera.macro"
        }
    }

    /// Accent color as 0xRRGGBB.
    var accentHex: UInt32 {
        switch self {
        case .claude: return 0xD97757
        case .codex: return 0x8B6CFF
        case .gentle: return 0xEC4A83
        }
    }
}
