
@testable import Aoxiang
import XCTest

class TestMiddleware: HTTPMiddleware {
    override func handle(_ req: HTTPRequest, _ res: HTTPResponse, next: @escaping MiddlewareNext) async {
        print("TestMiddleware start.")
        await next()
        print("TestMiddleware end.")
    }
}

final class MiddlewareTests: XCTestCase {
    func testMiddlewareIntercept() async throws {
        let server = HTTPServer()
        server.use { req, res, next async in
            res.send("[\(req.method)] \(req.path)")
            return

                    await next()
        }
        server.get("/") { _, res in
            res.send("OK")
        }
        try server.start(8080)

        let res = await fetch("/")
        XCTAssertEqual(res, "[GET] /")
    }
}
