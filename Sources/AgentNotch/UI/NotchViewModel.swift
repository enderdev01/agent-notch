import AppKit
import SwiftUI

enum NotchLayout {
    /// Panel is big enough for the largest expanded state.
    static let panelSize = CGSize(width: 480, height: 540)
    static let expandedWidth: CGFloat = 420
    static let earWidth: CGFloat = 34
    static let topRadius: CGFloat = 8
}

@MainActor
final class NotchViewModel: ObservableObject {
    @Published var hovering = false
    @Published var geometry = NotchGeometry(
        screenFrame: .zero, notchWidth: NotchGeometry.fallbackWidth, notchHeight: 32)
    /// Size of the currently visible black shape (reported by the view).
    @Published var shapeSize = CGSize(width: 200, height: 32)
    /// Horizontal shift of the visible shape from the screen center (idle shape hugs the left of the notch).
    @Published var shapeOffsetX: CGFloat = 0

    /// Bumped on every preference change so the views re-read `Preferences` immediately.
    @Published private(set) var prefsRevision = 0
    /// Session id whose row is under the mouse in the expanded list (drives the hover detail).
    @Published var hoveredSession: String?
    /// Measured height of the session list content (0 until the first layout).
    @Published var listContentHeight: CGFloat = 0

    init() {
        NotificationCenter.default.addObserver(forName: Preferences.changed, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.prefsRevision &+= 1 }
        }
    }

    /// `AGENT_NOTCH_REDUCE_MOTION=1` forces it on, to test the static path without touching system settings.
    var reduceMotion: Bool {
        ProcessInfo.processInfo.environment["AGENT_NOTCH_REDUCE_MOTION"] == "1"
            || NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }
}
