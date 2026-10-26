@testable import Aoxiang
import XCTest

final class HTTPResponseTests: XCTestCase {
    private let port: in_port_t = 18081

    func testNotFoundUsesMatchingReasonPhrase() throws {
        let server = HTTPServer()
        defer { server.stop() }
        try server.start(port)

        let response = try RawHTTPClient.get("/missing", port: UInt16(port))

        XCTAssertEqual(response.statusLine, "HTTP/1.1 404 Not Found")
        XCTAssertEqual(String(decoding: response.body, as: UTF8.self), "404 Not Found")
    }

    func testReasonPhraseFollowsStatusCode() throws {
        let server = HTTPServer()
        defer { server.stop() }
        server.get("/boom") { _, res in
            res.statusCode = 500
            res.send("boom")
        }
        try server.start(port)

        let response = try RawHTTPClient.get("/boom", port: UInt16(port))

        XCTAssertEqual(response.statusLine, "HTTP/1.1 500 Internal Server Error")
    }

    func testReasonPhraseCanBeOverridden() throws {
        let server = HTTPServer()
        defer { server.stop() }
        server.get("/custom") { _, res in
            res.statusCode = 418
            res.reasonPhrase = "Teapot Time"
            res.send("custom")
        }
        try server.start(port)

        let response = try RawHTTPClient.get("/custom", port: UInt16(port))

        XCTAssertEqual(response.statusLine, "HTTP/1.1 418 Teapot Time")
    }
}
