import AppKit

/// Where the notch is and how big it is on the chosen screen.
struct NotchGeometry: Equatable {
    var screenFrame: CGRect
    var notchWidth: CGFloat
    var notchHeight: CGFloat

    static let fallbackWidth: CGFloat = 200

    @MainActor
    static func current() -> NotchGeometry {
        let screen = NSScreen.screens.first { $0.safeAreaInsets.top > 0 } ?? NSScreen.main ?? NSScreen.screens[0]
        return NotchGeometry(screen: screen)
    }

    @MainActor
    init(screen: NSScreen) {
        screenFrame = screen.frame
        if screen.safeAreaInsets.top > 0,
           let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea {
            notchWidth = screen.frame.width - left.width - right.width
            notchHeight = screen.safeAreaInsets.top
        } else {
            notchWidth = Self.fallbackWidth
            notchHeight = max(NSStatusBar.system.thickness, 24)
        }
    }

    init(screenFrame: CGRect, notchWidth: CGFloat, notchHeight: CGFloat) {
        self.screenFrame = screenFrame
        self.notchWidth = notchWidth
        self.notchHeight = notchHeight
    }
}
