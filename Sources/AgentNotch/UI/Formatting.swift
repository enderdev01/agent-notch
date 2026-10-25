import Foundation

enum Formatting {
    /// Running clock: "2:05" under an hour, "1h02" after.
    static func clock(_ seconds: TimeInterval) -> String {
        let s = max(0, Int(seconds))
        if s >= 3600 { return String(format: "%dh%02d", s / 3600, s % 3600 / 60) }
        return String(format: "%d:%02d", s / 60, s % 60)
    }

    /// Total time worked: "45s", "12m", "1h 20m".
    static func duration(_ seconds: Double) -> String {
        let s = Int(seconds)
        if s >= 3600 { return "\(s / 3600)h \(s % 3600 / 60)m" }
        if s >= 60 { return "\(s / 60)m" }
        return "\(s)s"
    }
}
