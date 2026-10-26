@testable import Aoxiang
import XCTest

final class RequestLimitTests: XCTestCase {
    private let port: in_port_t = 18082

    func testMalformedRequestLineReturns400() throws {
        let server = makeServer()
        defer { server.stop() }
        try server.start(port)

        let response = try sendRaw("GARBAGE\r\n")

        XCTAssertEqual(response.statusLine, "HTTP/1.1 400 Bad Request")
    }

    func testMalformedHeaderReturns400() throws {
        let server = makeServer()
        defer { server.stop() }
        try server.start(port)

        let response = try sendRaw("GET / HTTP/1.1\r\nHost: localhost\r\nBrokenHeader\r\n")

        XCTAssertEqual(response.statusLine, "HTTP/1.1 400 Bad Request")
    }

    func testOversizedHeadersReturn431() throws {
        let server = makeServer()
        defer { server.stop() }
        try server.start(port)

        var request = "GET / HTTP/1.1\r\nHost: localhost\r\n"
        for index in 0 ..< 5 {
            request += "X-Pad-\(index): " + String(repeating: "a", count: 7000) + "\r\n"
        }

        let response = try sendRaw(request)

        XCTAssertEqual(response.statusLine, "HTTP/1.1 431 Request Header Fields Too Large")
    }

    func testOversizedBodyReturns413() throws {
        let server = makeServer()
        defer { server.stop() }
        server.maxRequestBodySize = 8
        try server.start(port)

        let response = try sendRaw("POST / HTTP/1.1\r\nHost: localhost\r\nContent-Length: 9\r\n\r\n")

        XCTAssertEqual(response.statusLine, "HTTP/1.1 413 Content Too Large")
    }

    func testChunkedRequestBodyReturns501() throws {
        let server = makeServer()
        defer { server.stop() }
        try server.start(port)

        let response = try sendRaw("POST / HTTP/1.1\r\nHost: localhost\r\nTransfer-Encoding: chunked\r\n\r\n")

        XCTAssertEqual(response.statusLine, "HTTP/1.1 501 Not Implemented")
    }

    private func makeServer() -> HTTPServer {
        let server = HTTPServer()
        server.get("/") { _, res in
            res.send("ok")
        }
        server.post("/") { _, res in
            res.send("ok")
        }
        return server
    }

    private func sendRaw(_ request: String) throws -> RawHTTPResponse {
        try RawHTTPClient.send(Data(request.utf8), port: UInt16(port))
    }
}
