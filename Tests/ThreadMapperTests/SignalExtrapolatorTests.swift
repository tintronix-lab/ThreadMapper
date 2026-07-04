import XCTest
@testable import ThreadMapper

final class SignalExtrapolatorOnlyTests: XCTestCase {
    func testCoverageScore_emptyDevices_isZero() throws {
        XCTAssertEqual(SignalExtrapolator.coverageScore(for: []), 0.0)
    }

    func testCoverageScore_withWeakRSSI_scoresDown() throws {
        let devices = [
            ThreadDevice(
                name: "Weak", manufacturer: "Test", productName: "X", deviceType: "Sensor",
                uniqueIdentifier: UUID(), isBorderRouter: false, isRouter: false, isSleepyEndDevice: true, rssi: -90
            )
        ]
        let score = SignalExtrapolator.coverageScore(for: devices)
        XCTAssertGreaterThanOrEqual(score, 0.0)
        XCTAssertLessThanOrEqual(score, 1.0)
    }

    func testRecommendations_noRouter() throws {
        let devices = [
            ThreadDevice(
                name: "Bulb", manufacturer: "Test", productName: "B", deviceType: "Lightbulb",
                uniqueIdentifier: UUID(), isBorderRouter: false, isRouter: false, isSleepyEndDevice: true
            )
        ]
        let recs = SignalExtrapolator.recommendations(for: devices)
        XCTAssertTrue(recs.contains { $0.contains("Add at least one Thread border router") })
    }
}
