import SwiftUI

/// Thin line under the collapsed notch, tinted by the working agents, with a soft sweeping highlight.
struct AccentLine: View {
    let colors: [Color]
    let reduceMotion: Bool

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { context in
            let period = 2.2
            let t = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: period) / period
            let phase = reduceMotion ? 0.5 : t
            Capsule()
                .fill(LinearGradient(colors: colors.count > 1 ? colors : [colors[0], colors[0]],
                                     startPoint: .leading, endPoint: .trailing))
                .overlay(
                    LinearGradient(colors: [.clear, .white.opacity(0.65), .clear],
                                   startPoint: UnitPoint(x: phase * 2 - 1, y: 0.5),
                                   endPoint: UnitPoint(x: phase * 2, y: 0.5))
                        .clipShape(Capsule())
                        .opacity(reduceMotion ? 0 : 1)
                )
                .frame(height: 2)
        }
    }
}
