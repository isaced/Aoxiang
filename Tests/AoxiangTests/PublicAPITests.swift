import Aoxiang
import Foundation
import XCTest

/// Exercises the documented API the way a library consumer does:
/// a plain `import Aoxiang`, without `@testable`.
final class PublicAPITests: XCTestCase {
    private final class Recorder: @unchecked Sendable {
        private let lock = NSLock()
        private var events: [String] = []

        func record(_ event: String) {
            lock.lock()
            defer { lock.unlock() }
            events.append(event)
        }

        var all: [String] {
            lock.lock()
            defer { lock.unlock() }
            return events
        }
    }

    private final class TraceMiddleware: HTTPMiddleware {
        private let recorder: Recorder

        init(recorder: Recorder) {
            self.recorder = recorder
            super.init()
        }

        override func handle(_ req: HTTPRequest, _ res: HTTPResponse, next: @escaping MiddlewareNext) async {
            recorder.record("middleware")
            await next()
        }
    }

    func testDocumentedAPIFromExternalModule() async throws {
        let port: in_port_t = 18180
        let recorder = Recorder()

        let server = HTTPServer()
        server.use(TraceMiddleware(recorder: recorder))
        server.use { _, _, next in
            recorder.record("closure")
            await next()
        }
        server.get("/users/:id") { req, res in
            recorder.record("handler")
            res.sendJSON(["id": req.params["id"] ?? ""])
        }
        defer { server.stop() }
        try server.start(port)

        let response = try RawHTTPClient.get("/users/42", port: UInt16(port))

        XCTAssertEqual(response.statusLine, "HTTP/1.1 200 OK")
        XCTAssertEqual(header(response, "content-type"), "application/json")
        XCTAssertEqual(String(decoding: response.body, as: UTF8.self), "{\"id\":\"42\"}")
        XCTAssertEqual(recorder.all, ["middleware", "closure", "handler"])
    }

    private func header(_ response: RawHTTPResponse, _ name: String) -> String? {
        response.headers.first { $0.name.lowercased() == name }?.value
    }
}
