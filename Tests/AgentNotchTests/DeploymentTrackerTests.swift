import XCTest
@testable import AgentNotch

final class DeploymentTrackerTests: XCTestCase {
    private func deployment(_ id: String, _ status: Deployment.Status) -> Deployment {
        Deployment(id: id, project: "project", repository: nil, commit: nil, author: nil, status: status)
    }

    func testOnlyNewTerminalTransitionsNotify() {
        var tracker = DeploymentTracker()
        XCTAssertTrue(tracker.update([deployment("old", .ready), deployment("active", .building)]).isEmpty)
        XCTAssertEqual(tracker.update([deployment("old", .ready), deployment("active", .ready)]).map(\.id), ["active"])
        XCTAssertTrue(tracker.update([deployment("active", .ready)]).isEmpty)
        XCTAssertEqual(tracker.update([deployment("new", .failed)]).map(\.id), ["new"])
    }

    /// A new run starts with an empty tracker, so work that finished while the app was closed is never announced.
    func testFinishedWhileClosedIsNotAnnounced() {
        var tracker = DeploymentTracker()
        XCTAssertTrue(tracker.update([deployment("closed", .ready)]).isEmpty)
        XCTAssertTrue(tracker.update([deployment("closed", .ready), deployment("live", .building)]).isEmpty)
        XCTAssertEqual(tracker.update([deployment("closed", .ready), deployment("live", .ready)]).map(\.id), ["live"])
        XCTAssertTrue(tracker.update([deployment("closed", .ready), deployment("live", .ready)]).isEmpty)
    }

    func testDuplicateItemsNotifyOnlyOnce() {
        var tracker = DeploymentTracker()
        _ = tracker.update([])
        XCTAssertEqual(tracker.update([deployment("a", .ready), deployment("a", .ready)]).count, 1)
    }
}
