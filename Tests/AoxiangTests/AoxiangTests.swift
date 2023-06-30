@testable import Aoxiang
import XCTest

final class AoxiangTests: XCTestCase {
    var server: HTTPServer!

    override func setUpWithError() throws {
        server = HTTPServer()
        try server.start(8080)
    }

    override func tearDown() {
        server.stop()
    }

//    func testExample() throws {
//        // create the expectation
//        let _ = expectation(description: "delay")
//
//        server.router.register("GET", path: "/stream") { _, res in
//            res.write("hi,")
//            res.write("Aoxiang.")
//            res.end()
//        }
//
//        waitForExpectations(timeout: 30)
//
//        XCTAssertNotEqual(server.socket?.sock, -1)
//    }

    func testSampleResponse() async throws {
        server.router.register("GET", path: "/testSampleResponse") { _, res in
            res.send("hello")
        }

        let res = await fetch("/testSampleResponse")
        XCTAssertEqual(res, "hello")
    }

    func testStreamResponse() async throws {
        server.router.register("GET", path: "/stream") { _, res in
            res.write("hi,")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                res.write("Aoxiang.")
                res.end()
            }
        }

        // TODO：need test each chunk
        let res = await fetch("/stream")
        XCTAssertEqual(res, "hi,Aoxiang.")
    }
}

extension AoxiangTests {
    func fetch(_ path: String) async -> String {
        let url = URL(string: "http://localhost:8080" + path)!
        let (data, _) = try! await URLSession.shared.data(from: url)
        return String(data: data, encoding: .utf8)!
    }
}
