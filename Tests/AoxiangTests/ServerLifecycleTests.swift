@testable import Aoxiang
import Darwin
import Foundation
import XCTest

final class ServerLifecycleTests: XCTestCase {
    func testRestartAfterStopServesRequests() async throws {
        let port: in_port_t = 18100
        let server = HTTPServer()
        server.get("/ping") { _, res in
            res.send("pong")
        }
        defer { server.stop() }

        try server.start(port)
        let first = try await body(at: "/ping", port: port)
        XCTAssertEqual(first, "pong")

        server.stop()
        try server.start(port)
        let second = try await body(at: "/ping", port: port)
        XCTAssertEqual(second, "pong")
    }

    func testRestartDoesNotDuplicateRouter() async throws {
        let port: in_port_t = 18101
        let counter = Counter()
        let server = HTTPServer()
        server.get("/count") { _, res in
            counter.increment()
            res.send("ok")
        }
        defer { server.stop() }

        try server.start(port)
        _ = try await body(at: "/count", port: port)

        server.stop()
        try server.start(port)
        _ = try await body(at: "/count", port: port)

        XCTAssertEqual(counter.value, 2)
    }

    func testStaleServerStopDoesNotCloseRestartedServer() async throws {
        let port: in_port_t = 18102
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

        let res = try await body(at: "/ping", port: port)
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

    private func body(at path: String, port: in_port_t) async throws -> String {
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

private final class Counter: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0

    func increment() {
        lock.lock()
        defer { lock.unlock() }
        count += 1
    }

    var value: Int {
        lock.lock()
        defer { lock.unlock() }
        return count
    }
}

extension ServerLifecycleTests {
    func testWriteAfterCloseDoesNotWriteToReusedDescriptor() throws {
        let listener = try Socket(port: 0)
        let fd = listener.sock
        listener.close()

        let path = NSTemporaryDirectory() + "aoxiang-socket-\(UUID().uuidString)"
        let fileDescriptor = open(path, O_WRONLY | O_CREAT | O_TRUNC, 0o600)
        guard fileDescriptor >= 0 else {
            throw RawHTTPClientError.socket("open failed: \(String(cString: strerror(errno)))")
        }
        defer {
            Darwin.close(fileDescriptor)
            unlink(path)
        }
        try XCTSkipUnless(fileDescriptor == fd, "File descriptor was not reused")

        XCTAssertThrowsError(try listener.write("leak"))

        let attributes = try FileManager.default.attributesOfItem(atPath: path)
        XCTAssertEqual(attributes[.size] as? Int, 0, "Write after close must not reach the reused descriptor")
    }
}

extension ServerLifecycleTests {
    func testConcurrentRequestsDuringStopDoNotCorruptState() async throws {
        let port: in_port_t = 18160
        let server = HTTPServer()
        server.get("/slow") { _, res in
            try? await Task.sleep(nanoseconds: 20_000_000)
            res.send("ok")
        }
        try server.start(port)

        await withTaskGroup(of: Void.self) { group in
            for _ in 0 ..< 10 {
                group.addTask {
                    _ = try? await self.body(at: "/slow", port: port)
                }
            }
            try? await Task.sleep(nanoseconds: 5_000_000)
            server.stop()
        }

        XCTAssertThrowsError(try RawHTTPClient.get("/slow", port: UInt16(port)))
    }
}
