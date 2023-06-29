@testable import Aoxiang
import XCTest

final class AoxiangTests: XCTestCase {
    func testExample() throws {
        // create the expectation
        let _ = expectation(description: "delay")

        let server = HTTPServer()
        try server.start(8080)

        waitForExpectations(timeout: 30)

        XCTAssertNotEqual(server.socket?.sock, -1)
    }
}
