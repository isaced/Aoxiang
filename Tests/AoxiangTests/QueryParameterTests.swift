@testable import Aoxiang
import XCTest

final class QueryParameterTests: XCTestCase {
    private let port: in_port_t = 18130

    func testQueryHelpersPreserveDuplicateKeys() throws {
        let server = HTTPServer()
        defer { server.stop() }
        server.get("/echo") { req, res in
            let first = req.queryValue("a") ?? "nil"
            let all = req.queryValues("a").joined(separator: ",")
            let missing = req.queryValue("missing") ?? "nil"
            let missingAll = req.queryValues("missing").count
            res.send("\(first)|\(all)|\(missing)|\(missingAll)")
        }
        try server.start(port)

        let response = try RawHTTPClient.get("/echo?a=1&a=2&b=3", port: UInt16(port))

        XCTAssertEqual(String(decoding: response.body, as: UTF8.self), "1|1,2|nil|0")
    }

    func testPercentEncodedQueryValueIsDecoded() throws {
        let server = HTTPServer()
        defer { server.stop() }
        server.get("/echo") { req, res in
            res.send(req.queryValue("name") ?? "nil")
        }
        try server.start(port)

        let response = try RawHTTPClient.get("/echo?name=%E4%BD%A0%E5%A5%BD", port: UInt16(port))

        XCTAssertEqual(String(decoding: response.body, as: UTF8.self), "你好")
    }
}
