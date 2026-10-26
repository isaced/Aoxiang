@testable import Aoxiang
import XCTest

final class SSETests: XCTestCase {
    private let port: in_port_t = 18170

    func testEventIDAndMultilineData() throws {
        let server = HTTPServer()
        defer { server.stop() }
        server.get("/sse") { _, res in
            let events = res.sendEvents()
            events.dispatchMessage("line1\nline2", event: "update", id: "7")
            events.close()
        }
        try server.start(port)

        let response = try RawHTTPClient.get("/sse", port: UInt16(port))

        XCTAssertEqual(header(response, "content-type"), "text/event-stream")
        XCTAssertEqual(
            String(decoding: response.body, as: UTF8.self),
            "event: update\r\nid: 7\r\ndata: line1\r\ndata: line2\r\n\r\ndata: \r\n\r\n"
        )
    }

    func testRetryField() throws {
        let server = HTTPServer()
        defer { server.stop() }
        server.get("/sse") { _, res in
            let events = res.sendEvents()
            events.dispatchRetry(1500)
            events.close()
        }
        try server.start(port)

        let response = try RawHTTPClient.get("/sse", port: UInt16(port))

        XCTAssertEqual(
            String(decoding: response.body, as: UTF8.self),
            "retry: 1500\r\n\r\ndata: \r\n\r\n"
        )
    }

    func testMessageWithoutEventOrID() throws {
        let server = HTTPServer()
        defer { server.stop() }
        server.get("/sse") { _, res in
            let events = res.sendEvents()
            events.dispatchMessage("hello")
            events.close()
        }
        try server.start(port)

        let response = try RawHTTPClient.get("/sse", port: UInt16(port))

        XCTAssertEqual(
            String(decoding: response.body, as: UTF8.self),
            "data: hello\r\n\r\ndata: \r\n\r\n"
        )
    }

    private func header(_ response: RawHTTPResponse, _ name: String) -> String? {
        response.headers.first { $0.name.lowercased() == name }?.value
    }
}
