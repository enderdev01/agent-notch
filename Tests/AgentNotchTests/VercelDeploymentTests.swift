import XCTest
@testable import AgentNotch

final class VercelDeploymentTests: XCTestCase {
    func testDecodesDeploymentMetadataAndState() throws {
        let json = #"{"deployments":[{"uid":"dpl_1","name":"app","state":"BUILDING","meta":{"githubRepo":"example","githubCommitSha":"abcdef123","githubCommitAuthorName":"Ada"}}],"pagination":{"next":null}}"#
        let page = try JSONDecoder().decode(DeploymentPage.self, from: Data(json.utf8))
        let deployment = try XCTUnwrap(page.deployments.first?.deployment)
        XCTAssertEqual(deployment.status, .building)
        XCTAssertEqual(deployment.repository, "example")
        XCTAssertEqual(deployment.author, "Ada")
        XCTAssertEqual(deployment.commit, "abcdef123")
    }

    func testUnknownStateAndMissingMetadata() throws {
        let json = #"{"deployments":[{"uid":"dpl_2","name":"app","state":"BLOCKED"}]}"#
        let page = try JSONDecoder().decode(DeploymentPage.self, from: Data(json.utf8))
        XCTAssertEqual(page.deployments.first?.deployment.status, .unknown)
        XCTAssertNil(page.deployments.first?.deployment.author)
    }

    func testPaginationAcceptsLastPageAndRejectsRepeatedCursor() throws {
        let last = try JSONDecoder().decode(DeploymentPage.self, from: Data(#"{"deployments":[],"pagination":{"next":null}}"#.utf8))
        XCTAssertNil(try last.nextPage(after: nil))
        XCTAssertNil(try last.nextPage(after: 123))
        let next = try JSONDecoder().decode(DeploymentPage.self, from: Data(#"{"deployments":[],"pagination":{"next":123}}"#.utf8))
        XCTAssertEqual(try next.nextPage(after: nil), 123)
        XCTAssertThrowsError(try next.nextPage(after: 123))
    }
}
