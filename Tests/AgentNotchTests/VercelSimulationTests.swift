import XCTest
@testable import AgentNotch

@MainActor
final class VercelSimulationTests: XCTestCase {
    func testSimulationMovesThroughBuildingAndCompletion() {
        let monitor = VercelMonitor()
        monitor.simulate(.building)
        XCTAssertTrue(monitor.active)
        XCTAssertEqual(monitor.deployments.first?.status, .building)
        monitor.simulate(.ready)
        XCTAssertFalse(monitor.active)
        XCTAssertEqual(monitor.deployments.first?.status, .ready)
        XCTAssertEqual(monitor.deployments.first?.repository, "example/repo")
        monitor.simulate(.building)
        monitor.simulate(.failed)
        XCTAssertFalse(monitor.active)
        XCTAssertEqual(monitor.deployments.first?.status, .failed)
    }
}
