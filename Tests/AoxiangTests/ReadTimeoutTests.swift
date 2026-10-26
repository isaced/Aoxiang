@testable import Aoxiang
import XCTest

final class ReadTimeoutTests: XCTestCase {
    private let port: in_port_t = 18120

    func testTimeoutIsDisabledByDefault() {
        XCTAssertEqual(HTTPServer().readTimeout, 0)
    }

    func testIncompleteRequestIsClosedAfterTimeout() throws {
        let server = HTTPServer()
        server.readTimeout = 1
        defer { server.stop() }
        try server.start(port)

        let start = Date()
        let response = try RawHTTPClient.send(Data("GET /".utf8), port: UInt16(port))
        let elapsed = Date().timeIntervalSince(start)

        XCTAssertEqual(response.statusLine, "")
        XCTAssertGreaterThanOrEqual(elapsed, 0.8)
        XCTAssertLessThan(elapsed, 8)
    }

    func testRequestsCompleteWithTimeoutEnabled() throws {
        let server = HTTPServer()
        server.readTimeout = 5
        server.get("/ping") { _, res in
            res.send("pong")
        }
        defer { server.stop() }
        try server.start(port + 1)

        let response = try RawHTTPClient.get("/ping", port: UInt16(port + 1))

        XCTAssertEqual(response.statusLine, "HTTP/1.1 200 OK")
        XCTAssertEqual(String(decoding: response.body, as: UTF8.self), "pong")
    }
}
