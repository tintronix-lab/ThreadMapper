@testable import ThreadMapper
import XCTest

/// Covers `NotificationService.deepLink(forRequestID:)`, the routing that a
/// notification tap uses. The device routes encode the `uniqueIdentifier` in the
/// request id; `first-seen-` was previously unhandled (tapping a "New Thread
/// Device" alert did nothing), so these pin the fix and the fallbacks.
final class NotificationDeepLinkTests: XCTestCase {

    func testOfflineRequestRoutesToDeviceDetail() {
        let uuid = UUID()
        XCTAssertEqual(
            NotificationService.deepLink(forRequestID: "offline-\(uuid.uuidString)"),
            .deviceDetail(uuid)
        )
    }

    func testFirstSeenRequestRoutesToDeviceDetail() {
        let uuid = UUID()
        XCTAssertEqual(
            NotificationService.deepLink(forRequestID: "first-seen-\(uuid.uuidString)"),
            .deviceDetail(uuid)
        )
    }

    func testMalformedDeviceUUIDFallsBackToDashboard() {
        XCTAssertEqual(NotificationService.deepLink(forRequestID: "offline-not-a-uuid"), .dashboard)
        XCTAssertEqual(NotificationService.deepLink(forRequestID: "first-seen-"), .dashboard)
    }

    func testHealthDropRoutesToDashboard() {
        XCTAssertEqual(NotificationService.deepLink(forRequestID: "health-drop-123456"), .dashboard)
    }

    func testTopologyAndWeeklyRouteToActivity() {
        XCTAssertEqual(NotificationService.deepLink(forRequestID: "topology-999"), .activity)
        XCTAssertEqual(NotificationService.deepLink(forRequestID: "weekly-report"), .activity)
    }

    func testUnknownRequestLeavesNavigationUnchanged() {
        XCTAssertNil(NotificationService.deepLink(forRequestID: "ai-insight-42"))
        XCTAssertNil(NotificationService.deepLink(forRequestID: ""))
    }
}
