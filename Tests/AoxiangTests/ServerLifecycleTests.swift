@testable import Aoxiang
import Darwin
import XCTest

final class ServerLifecycleTests: XCTestCase {
    private let port: in_port_t = 18080

    func testRestartAfterStopServesRequests() async throws {
        let server = HTTPServer()
        server.get("/ping") { _, res in
            res.send("pong")
        }
        defer { server.stop() }

        try server.start(port)
        let first = try await body(at: "/ping")
        XCTAssertEqual(first, "pong")

        server.stop()
        try server.start(port)
        let second = try await body(at: "/ping")
        XCTAssertEqual(second, "pong")
    }

    func testStaleServerStopDoesNotCloseRestartedServer() async throws {
        let first = HTTPServer()
        first.get("/ping") { _, res in
            res.send("pong")
        }
        try first.start(port)
        first.stop()

        let second = HTTPServer()
        second.get("/ping") { _, res in
            res.send("pong")
        }
        try second.start(port)
        defer { second.stop() }

        // A late stop() from the first server (for example, its accept loop
        // exiting) must not close the descriptor now owned by the second one.
        first.stop()

        let res = try await body(at: "/ping")
        XCTAssertEqual(res, "pong")
    }

    func testSocketCloseIsIdempotent() throws {
        let listener = try Socket(port: 0)
        let fd = listener.sock
        listener.close()

        let reused = try Socket(port: 0)
        defer { reused.close() }
        try XCTSkipUnless(reused.sock == fd, "File descriptor was not reused")

        listener.close()
        XCTAssertNotEqual(fcntl(reused.sock, F_GETFD), -1, "Second close must not close the reused descriptor")
    }

    private func body(at path: String) async throws -> String {
        // Use an ephemeral session so connections are not pooled across the
        // server restarts these tests exercise, and fail fast instead of
        // waiting for the 60s default when something goes wrong.
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 10
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }

        let url = URL(string: "http://127.0.0.1:\(port)\(path)")!
        let (data, _) = try await session.data(from: url)
        return String(decoding: data, as: UTF8.self)
    }
}
