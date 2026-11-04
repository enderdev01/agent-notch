import XCTest
@testable import AgentNotch

final class NotchLayoutTests: XCTestCase {
    func testPanelWidthFitsNotchAndScreen() {
        func size(screen: CGFloat, notch: CGFloat) -> CGSize {
            NotchLayout.panelSize(for: NotchGeometry(
                screenFrame: CGRect(x: 0, y: 0, width: screen, height: 900),
                notchWidth: notch, notchHeight: 32))
        }

        XCTAssertEqual(size(screen: 1440, notch: 200).width, 480)
        XCTAssertEqual(size(screen: 1440, notch: 500).width, 730)
        XCTAssertEqual(size(screen: 600, notch: 500).width, 600)
    }

    @MainActor
    func testCollapsedTrackingDoesNotReachBrowserTabs() {
        let geometry = NotchGeometry(screenFrame: CGRect(x: 0, y: 0, width: 1440, height: 900),
                                     notchWidth: 200, notchHeight: 32)
        let shape = CGSize(width: 280, height: 36)
        let collapsed = NotchPanelController.trackingRect(geometry: geometry, shape: shape, offsetX: 0, expanded: false)
        XCTAssertTrue(collapsed.contains(CGPoint(x: 720, y: 869)))
        XCTAssertFalse(collapsed.contains(CGPoint(x: 720, y: 867)))

        let expanded = NotchPanelController.trackingRect(geometry: geometry, shape: CGSize(width: 420, height: 300),
                                                         offsetX: 0, expanded: true)
        XCTAssertTrue(expanded.contains(CGPoint(x: 720, y: 650)))
    }
}
