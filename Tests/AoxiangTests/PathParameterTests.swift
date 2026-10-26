@testable import Aoxiang
import XCTest

final class PathParameterTests: XCTestCase {
    private let port: in_port_t = 18150

    func testSingleParameterIsPopulated() throws {
        let server = HTTPServer()
        defer { server.stop() }
        server.get("/users/:id") { req, res in
            res.send(req.params["id"] ?? "nil")
        }
        try server.start(port)

        let response = try RawHTTPClient.get("/users/42", port: UInt16(port))

        XCTAssertEqual(String(decoding: response.body, as: UTF8.self), "42")
    }

    func testMultipleParameters() throws {
        let server = HTTPServer()
        defer { server.stop() }
        server.get("/users/:id/posts/:postId") { req, res in
            res.send("\(req.params["id"] ?? "-")-\(req.params["postId"] ?? "-")")
        }
        try server.start(port)

        let response = try RawHTTPClient.get("/users/42/posts/7", port: UInt16(port))

        XCTAssertEqual(String(decoding: response.body, as: UTF8.self), "42-7")
    }

    func testExactRouteTakesPrecedence() throws {
        let server = HTTPServer()
        defer { server.stop() }
        server.get("/users/:id") { _, res in
            res.send("param")
        }
        server.get("/users/me") { _, res in
            res.send("static")
        }
        try server.start(port)

        let response = try RawHTTPClient.get("/users/me", port: UInt16(port))

        XCTAssertEqual(response.statusLine, "HTTP/1.1 200 OK")
        XCTAssertEqual(String(decoding: response.body, as: UTF8.self), "static")
    }

    func testTrailingSlashDoesNotMatchEmptyParameter() throws {
        let server = HTTPServer()
        defer { server.stop() }
        server.get("/users/:id") { req, res in
            res.send(req.params["id"] ?? "nil")
        }
        try server.start(port)

        let response = try RawHTTPClient.get("/users/", port: UInt16(port))

        XCTAssertEqual(response.statusLine, "HTTP/1.1 404 Not Found")
    }

    func testParameterRoutesAreMethodScoped() throws {
        let server = HTTPServer()
        defer { server.stop() }
        server.post("/items/:id") { _, res in
            res.send("posted")
        }
        try server.start(port)

        let response = try RawHTTPClient.get("/items/1", port: UInt16(port))

        XCTAssertEqual(response.statusLine, "HTTP/1.1 404 Not Found")
    }
}
