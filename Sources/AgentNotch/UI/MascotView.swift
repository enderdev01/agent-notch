import SwiftUI

enum MascotMood: Hashable {
    case sleeping, working, waiting, done, error
    /// Awake and blinking right after activity, then drowsier until asleep (see `MascotBody` timings).
    case idle(since: Date)

    /// Idle mood from an agent's sessions: its latest activity decides how sleepy it is.
    static func resting(_ sessions: some Sequence<AgentSession>) -> MascotMood {
        sessions.map(\.updatedAt).max().map { .idle(since: $0) } ?? .sleeping
    }
}

/// A pixel-art agent mascot that reacts to what the agent is doing.
/// Time-driven (TimelineView) so it needs no timers; static when Reduce Motion is on.
struct MascotView: View {
    let agent: AgentKind
    let mood: MascotMood
    let size: CGFloat
    let reduceMotion: Bool

    var body: some View {
        // New identity per mood so each mood's clock starts at zero.
        MascotBody(agent: agent, mood: mood, size: size, reduceMotion: reduceMotion)
            .id(mood)
    }
}

private struct MascotPose {
    var dx: CGFloat = 0
    var dy: CGFloat = 0
    var rotation: Double = 0
    var scaleX: CGFloat = 1
    var scaleY: CGFloat = 1
}

/// Remembers when the current mood began, so animations can run on time-since-mood-start.
private final class MascotClock: ObservableObject {
    let start = Date()
}

private struct MascotBody: View {
    let agent: AgentKind
    let mood: MascotMood
    let size: CGFloat
    let reduceMotion: Bool

    // @StateObject (not @State): the CommandLineTools toolchain has no SwiftUI macro plugin.
    @StateObject private var clock = MascotClock()

    /// What the mascot looks like right now; `.idle` moods resolve to one of the last three over time.
    private enum Look: Equatable {
        case sleeping, working, waiting, done, error, awake
        case drowsy(Double)  // 0 (just nodding off) ... 1 (about to fall asleep)
    }

    private func look(at date: Date) -> Look {
        switch mood {
        case .sleeping: return .sleeping
        case .working: return .working
        case .waiting: return .waiting
        case .done: return .done
        case .error: return .error
        case .idle(let since):
            // Awake for the first third of the user's "falls asleep after" time, drowsy for the rest.
            let asleepAfter = Preferences.sleepAfter
            let awakeFor = asleepAfter / 3
            let age = date.timeIntervalSince(since)
            if age < awakeFor { return .awake }
            if age >= asleepAfter { return .sleeping }
            return .drowsy((age - awakeFor) / (asleepAfter - awakeFor))
        }
    }

    var body: some View {
        // Reduce Motion still ticks every 5 s (poses stay static) so idle can move on from awake to asleep.
        TimelineView(.animation(minimumInterval: reduceMotion ? 5 : nil)) { context in
            let t = reduceMotion ? 0 : context.date.timeIntervalSince(clock.start)
            let look = look(at: context.date)
            let pose = reduceMotion ? MascotPose() : pose(look, at: t)
            ZStack {
                sprite(variant: spriteVariant(look, at: t))
                    .frame(width: size, height: size)
                    .scaleEffect(x: pose.scaleX, y: pose.scaleY, anchor: .bottom)
                    .rotationEffect(.degrees(pose.rotation), anchor: .bottom)
                    .offset(x: pose.dx, y: pose.dy)
                if look == .done, !reduceMotion { sparkles(at: t) }
                if look == .waiting { alertBadge(at: t) }
                if look == .error { errorBadge(at: t) }
                if look == .sleeping { zzz(at: t) }
            }
            .frame(width: size, height: size)
        }
    }

    /// Working flips between the base and "work" frames; awake blinks briefly; drowsy keeps its eyes
    /// shut for longer and longer; the other moods hold one pose.
    private func spriteVariant(_ look: Look, at t: Double) -> String? {
        switch look {
        case .sleeping: return "sleep"
        case .waiting: return "alert"
        case .done: return "done"
        case .error: return "error"
        case .working: return Int(t / 0.3).isMultiple(of: 2) ? "work" : nil
        case .awake: return t.truncatingRemainder(dividingBy: 3.2) > 3.06 ? "blink" : nil
        case .drowsy(let p):
            let cycle = 2.4
            let eyesShut = 0.3 + 1.4 * p
            return t.truncatingRemainder(dividingBy: cycle) > cycle - eyesShut ? "blink" : "drowsy"
        }
    }

    @ViewBuilder private func sprite(variant: String?) -> some View {
        if let image = MascotSprites.image(for: agent, variant: variant) {
            Image(nsImage: image).resizable().interpolation(.high).scaledToFit()
        } else {
            Image(systemName: agent.symbol)
                .resizable().scaledToFit().padding(size * 0.15)
                .foregroundStyle(agent.color)
        }
    }

    // MARK: Poses

    private func pose(_ look: Look, at t: Double) -> MascotPose {
        switch look {
        case .sleeping: return sleepingPose(t)
        case .working: return workingPose(t)
        case .waiting: return waitingPose(t)
        case .done: return donePose(t)
        case .error: return errorPose(t)
        case .awake: return MascotPose(scaleY: 1 + 0.02 * sin(t * 2 * .pi / 2.4))
        case .drowsy(let p): return drowsyPose(t, p)
        }
    }

    /// A quick tremble of shock, then a slumped, slowly swaying stance.
    private func errorPose(_ t: Double) -> MascotPose {
        let tremble = t < 0.6 ? sin(t * 2 * .pi * 7) * size * 0.05 * (1 - t / 0.6) : 0
        return MascotPose(dx: tremble, dy: size * 0.02, rotation: sin(t * 2 * .pi / 3) * 1.5, scaleY: 0.97)
    }

    /// Head droops and bobs back up; the nod gets deeper as sleep gets closer.
    private func drowsyPose(_ t: Double, _ p: Double) -> MascotPose {
        let nod = (1 - cos(t * 2 * .pi / 2.4)) / 2 * (0.3 + 0.7 * p)
        return MascotPose(dy: nod * size * 0.03, rotation: nod * 7, scaleY: 1 - 0.03 * nod)
    }

    /// Slow, deep breathing with a tiny sway.
    private func sleepingPose(_ t: Double) -> MascotPose {
        let breath = sin(t * 2 * .pi / 3.6)
        return MascotPose(rotation: breath * 1.5, scaleX: 1 - 0.02 * breath, scaleY: 1 + 0.045 * breath)
    }

    /// Each agent has its own rhythm so you can tell them apart at a glance.
    private func workingPose(_ t: Double) -> MascotPose {
        switch agent {
        case .claude:
            // Bouncy hops with squash on landing.
            let h = abs(sin(t * .pi / 0.6))
            return MascotPose(dy: -h * size * 0.14,
                              scaleX: 1 - 0.06 * h + 0.05 * (1 - h),
                              scaleY: 1 + 0.07 * h - 0.06 * (1 - h))
        case .codex:
            // Fast "typing" jitter with a slight head tilt.
            let tap = abs(sin(t * 2 * .pi * 3.4))
            return MascotPose(dy: -tap * size * 0.06,
                              rotation: sin(t * 2 * .pi * 1.7) * 3.5)
        case .gentle:
            // Slow leafy sway.
            return MascotPose(dx: sin(t * 2 * .pi / 1.6) * size * 0.04,
                              dy: -abs(sin(t * .pi / 1.6)) * size * 0.04,
                              rotation: sin(t * 2 * .pi / 1.6) * 9)
        }
    }

    /// Short nervous shake, then a pause, repeating.
    private func waitingPose(_ t: Double) -> MascotPose {
        let cycle = 1.5
        let phase = t.truncatingRemainder(dividingBy: cycle)
        guard phase < 0.7 else { return MascotPose() }
        let envelope = sin(phase / 0.7 * .pi)
        return MascotPose(dx: sin(phase * 2 * .pi * 6) * size * 0.07 * envelope,
                          rotation: sin(phase * 2 * .pi * 6) * 6 * envelope)
    }

    /// Two hops (big, small) with squash and stretch.
    private func donePose(_ t: Double) -> MascotPose {
        let (from, length, height): (Double, Double, CGFloat) = t < 0.5
            ? (0, 0.5, 0.2) : (0.5, 0.4, 0.09)
        let local = t - from
        guard t < 0.9, local >= 0 else { return MascotPose() }
        let p = local / length
        let lift = sin(p * .pi)
        return MascotPose(dy: -lift * size * height,
                          scaleX: 1 - 0.05 * lift, scaleY: 1 + 0.08 * lift)
    }

    // MARK: Decorations

    private func sparkles(at t: Double) -> some View {
        let life = 1.4
        let p = min(max(t / life, 0), 1)
        return ZStack {
            ForEach(0..<6, id: \.self) { i in
                let angle = Double(i) / 6 * 2 * .pi + 0.4
                let radius = size * (0.45 + 0.35 * p)
                Image(systemName: "sparkle")
                    .font(.system(size: size * 0.3, weight: .bold))
                    .foregroundStyle(i.isMultiple(of: 2) ? agent.color : .white)
                    .scaleEffect(1 - 0.5 * p)
                    .opacity(1 - p)
                    .offset(x: cos(angle) * radius, y: sin(angle) * radius)
            }
        }
        .allowsHitTesting(false)
    }

    /// Three "z" glyphs that float up from the mascot's head and fade, staggered.
    private func zzz(at t: Double) -> some View {
        let cycle = 3.6
        return ZStack {
            ForEach(reduceMotion ? [0] : [0, 1, 2], id: \.self) { i in
                let p = reduceMotion ? 0.5 : (t / cycle + Double(i) / 3).truncatingRemainder(dividingBy: 1)
                Text("z")
                    .font(.system(size: size * (0.26 + 0.16 * p), weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .opacity(reduceMotion ? 0.8 : sin(p * .pi) * 0.9)
                    .offset(x: size * (0.42 + 0.22 * p), y: -size * (0.05 + 0.4 * p))
            }
        }
        .allowsHitTesting(false)
    }

    private func errorBadge(at t: Double) -> some View {
        let d = size * 0.42
        return Image(systemName: "xmark")
            .font(.system(size: d * 0.55, weight: .heavy))
            .foregroundStyle(.white)
            .frame(width: d, height: d)
            .background(Circle().fill(Color(hex: 0xE5484D)))
            .offset(x: size * 0.42, y: -size * 0.38)
            .allowsHitTesting(false)
    }

    private func alertBadge(at t: Double) -> some View {
        let pulse = reduceMotion ? 1 : (sin(t * 2 * .pi / 0.9) + 1) / 2
        let d = size * 0.42
        return Text("!")
            .font(.system(size: d * 0.78, weight: .heavy))
            .foregroundStyle(.black)
            .frame(width: d, height: d)
            .background(Circle().fill(Color(hex: 0xFFB020)))
            .scaleEffect(0.9 + 0.15 * pulse)
            .offset(x: size * 0.42, y: -size * 0.38)
            .allowsHitTesting(false)
    }
}
