import SwiftUI

/// Small status dot that breathes. Time-driven (no @State) so it needs no view-local storage.
struct PulsingDot: View {
    let color: Color
    let animated: Bool

    var body: some View {
        TimelineView(.animation(paused: !animated)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let pulse = animated ? (sin(t * 2 * .pi / 1.8) + 1) / 2 : 1
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
                .shadow(color: color.opacity(0.8), radius: 1 + 3 * pulse)
                .scaleEffect(0.78 + 0.22 * pulse)
        }
    }
}
