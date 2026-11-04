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

    func testRestartAndStalePollDoNotRepeatNotifications() throws {
        var tracker = DeploymentTracker()
        _ = tracker.update([deployment("deploy", .building)])
        XCTAssertEqual(tracker.update([deployment("deploy", .ready)]).count, 1)
        tracker = try JSONDecoder().decode(DeploymentTracker.self, from: JSONEncoder().encode(tracker))
        XCTAssertTrue(tracker.update([deployment("deploy", .building)]).isEmpty)
        XCTAssertTrue(tracker.update([deployment("deploy", .ready)]).isEmpty)
    }

    func testDuplicateItemsNotifyOnlyOnce() {
        var tracker = DeploymentTracker()
        _ = tracker.update([])
        XCTAssertEqual(tracker.update([deployment("a", .ready), deployment("a", .ready)]).count, 1)
    }
}
