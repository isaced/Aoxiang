#if os(iOS)
@testable import Aoxiang
import XCTest

final class iOSBackgroundTaskTests: XCTestCase {
    func testRepeatedRestartsDoNotAccumulateLifecycleObservers() throws {
        let server = HTTPServer()
        defer { server.stop() }

        for _ in 0 ..< 3 {
            try server.start(18110)
            XCTAssertTrue(server.isObservingLifecycle)
            server.stop()
            XCTAssertFalse(server.isObservingLifecycle)
        }
    }

    func testAutoSuspendDisabledDoesNotObserveLifecycle() throws {
        let server = HTTPServer()
        server.automaticallySuspendInBackground = false
        defer { server.stop() }

        try server.start(18111)
        XCTAssertFalse(server.isObservingLifecycle)
    }
}
#endif
