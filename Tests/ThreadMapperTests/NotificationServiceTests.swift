@testable import ThreadMapper
import XCTest

final class NotificationServiceQuietHoursTests: XCTestCase {

    func testNonWrappingWindow_startInclusiveEndExclusive() {
        // Quiet 09:00–17:00
        XCTAssertFalse(NotificationService.isInQuietHours(hour: 8, start: 9, end: 17))
        XCTAssertTrue(NotificationService.isInQuietHours(hour: 9, start: 9, end: 17))   // start inclusive
        XCTAssertTrue(NotificationService.isInQuietHours(hour: 16, start: 9, end: 17))
        XCTAssertFalse(NotificationService.isInQuietHours(hour: 17, start: 9, end: 17)) // end exclusive
    }

    func testWrappingMidnightWindow() {
        // Quiet 22:00–07:00
        XCTAssertTrue(NotificationService.isInQuietHours(hour: 22, start: 22, end: 7))  // start inclusive
        XCTAssertTrue(NotificationService.isInQuietHours(hour: 23, start: 22, end: 7))
        XCTAssertTrue(NotificationService.isInQuietHours(hour: 0, start: 22, end: 7))
        XCTAssertTrue(NotificationService.isInQuietHours(hour: 6, start: 22, end: 7))
        XCTAssertFalse(NotificationService.isInQuietHours(hour: 7, start: 22, end: 7))  // end exclusive
        XCTAssertFalse(NotificationService.isInQuietHours(hour: 12, start: 22, end: 7))
    }
}
