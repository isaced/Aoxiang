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
        let first = try await fetch("/ping", port: Int(port))
        XCTAssertEqual(first, "pong")

        server.stop()
        try server.start(port)
        let second = try await fetch("/ping", port: Int(port))
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

        let res = try await fetch("/ping", port: Int(port))
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
}
