@testable import Aoxiang
import XCTest

final class ResponseBodyTests: XCTestCase {
    private let port: in_port_t = 18140

    func testStringResponseSetsLengthAndType() throws {
        let server = HTTPServer()
        defer { server.stop() }
        server.get("/text") { _, res in
            res.send("你好")
        }
        try server.start(port)

        let response = try RawHTTPClient.get("/text", port: UInt16(port))

        XCTAssertEqual(header(response, "content-length"), "6")
        XCTAssertEqual(header(response, "content-type"), "text/plain; charset=utf-8")
        XCTAssertEqual(String(decoding: response.body, as: UTF8.self), "你好")
    }

    func testDataResponsePreservesBytes() throws {
        let bytes: [UInt8] = [0, 1, 2, 255, 254]
        let server = HTTPServer()
        defer { server.stop() }
        server.get("/data") { _, res in
            res.send(Data(bytes), contentType: "application/octet-stream")
        }
        try server.start(port)

        let response = try RawHTTPClient.get("/data", port: UInt16(port))

        XCTAssertEqual(header(response, "content-length"), "5")
        XCTAssertEqual(header(response, "content-type"), "application/octet-stream")
        XCTAssertEqual(response.body, Data(bytes))
    }

    func testJSONResponseEncodesValue() throws {
        struct Payload: Codable, Equatable {
            let id: Int
            let name: String
        }
        let payload = Payload(id: 1, name: "Aoxiang")

        let server = HTTPServer()
        defer { server.stop() }
        server.get("/json") { _, res in
            res.sendJSON(payload)
        }
        try server.start(port)

        let response = try RawHTTPClient.get("/json", port: UInt16(port))

        XCTAssertEqual(header(response, "content-type"), "application/json")
        XCTAssertEqual(header(response, "content-length"), String(response.body.count))
        XCTAssertEqual(try JSONDecoder().decode(Payload.self, from: response.body), payload)
    }

    private func header(_ response: RawHTTPResponse, _ name: String) -> String? {
        response.headers.first { $0.name.lowercased() == name }?.value
    }
}
