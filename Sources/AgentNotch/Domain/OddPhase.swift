/// Gentle Shell's ODD phases, as the orchestrator reports them through its `gentle_odd_phase` tool.
enum OddPhase: String, Hashable, Sendable {
    case authorizing, exploring, researching, deciding, planning, implementing, checking, closing

    /// Suffix of the `<agent>-work-<group>` sprite; nil keeps the plain work sprite.
    var spriteGroup: String? {
        switch self {
        case .exploring, .researching: return "explore"
        case .authorizing, .deciding, .planning: return "think"
        case .checking: return "check"
        case .closing: return "close"
        case .implementing: return nil
        }
    }
}
