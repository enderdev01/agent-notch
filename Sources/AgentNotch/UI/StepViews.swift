import SwiftUI

/// Pending = empty ring, running = spinning arc, done = filled check.
struct StepIcon: View {
    let state: Step.State
    let color: Color
    let size: CGFloat
    let reduceMotion: Bool

    var body: some View {
        switch state {
        case .done:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: size))
                .foregroundStyle(color)
        case .pending:
            Circle().stroke(.white.opacity(0.3), lineWidth: 1.2)
                .frame(width: size - 1.5, height: size - 1.5)
                .frame(width: size, height: size)
        case .running:
            TimelineView(.animation(paused: reduceMotion)) { context in
                let angle = reduceMotion ? 0 : context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 0.9) / 0.9 * 360
                Circle().trim(from: 0, to: 0.7)
                    .stroke(color, style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
                    .rotationEffect(.degrees(angle))
                    .frame(width: size - 2, height: size - 2)
                    .frame(width: size, height: size)
            }
        }
    }
}

/// Horizontal progress for the collapsed notch: one icon per step, the active step's title, and "2/5".
struct StepStrip: View {
    let steps: [Step]
    let color: Color
    let reduceMotion: Bool

    private static let maxIcons = 10

    private var done: Int { steps.filter { $0.state == .done }.count }
    private var current: Step? { steps.first { $0.state == .running } ?? steps.first { $0.state == .pending } }

    /// With more steps than fit, slide a window that keeps the active step in view.
    private var visible: [Step] {
        guard steps.count > Self.maxIcons else { return steps }
        let at = steps.firstIndex { $0.state == .running } ?? steps.firstIndex { $0.state == .pending } ?? steps.count - 1
        let start = min(max(0, at - 3), steps.count - Self.maxIcons)
        return Array(steps[start..<start + Self.maxIcons])
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 5) {
                ForEach(Array(visible.enumerated()), id: \.offset) { _, step in
                    StepIcon(state: step.state, color: color, size: 11, reduceMotion: reduceMotion)
                }
                Spacer(minLength: 4)
                Text("\(done)/\(steps.count)")
                    .font(.system(size: 10, weight: .medium).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.55))
            }
            if let current {
                Text(current.title)
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 9)
    }
}

/// Vertical checklist for an expanded session row.
struct StepList: View {
    static let maxRows = 8

    let steps: [Step]
    let color: Color
    let reduceMotion: Bool

    /// Rows actually drawn (the list is capped; the rest folds into "+N more").
    static func rows(for steps: [Step]) -> Int { min(steps.count, maxRows) + (steps.count > maxRows ? 1 : 0) }

    /// Cap that always keeps the active step visible.
    private var shown: [Step] {
        guard steps.count > Self.maxRows else { return steps }
        let at = steps.firstIndex { $0.state == .running } ?? steps.firstIndex { $0.state == .pending } ?? 0
        let start = min(max(0, at - 2), steps.count - Self.maxRows)
        return Array(steps[start..<start + Self.maxRows])
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            ForEach(Array(shown.enumerated()), id: \.offset) { _, step in
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    StepIcon(state: step.state, color: color, size: 10, reduceMotion: reduceMotion)
                        .alignmentGuide(.firstTextBaseline) { $0[.bottom] - 1 }
                    Text(step.title)
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(step.state == .running ? 0.9 : step.state == .done ? 0.5 : 0.6))
                        .strikethrough(step.state == .done, color: .white.opacity(0.3))
                        .lineLimit(1)
                }
            }
            if steps.count > Self.maxRows {
                Text(L("+%ld more", steps.count - shown.count))
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.35))
            }
        }
        .padding(.top, 3)
    }
}
