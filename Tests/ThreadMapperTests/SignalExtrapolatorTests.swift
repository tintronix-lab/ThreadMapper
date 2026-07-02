import XCTest
@testable import ThreadMapper

final class SignalExtrapolatorTests: XCTestCase {
    func testCoverageScore_emptyDevices_isZero() throws {
        XCTAssertEqual(SignalExtrapolator.coverageScore(for: []), 0.0)
    }

    func testCoverageScore_withWeakRSSI_scoresDown() throws {
        let devices = [
            ThreadDevice(
                name: "Weak",
                manufacturer: "Test",
                productName: "X",
                deviceType: "Sensor",
                uniqueIdentifier: "w",
                rssi: -90
            )
        ]
        let score = SignalExtrapolator.coverageScore(for: devices)
        XCTAssertGreaterThanOrEqual(score, 0.0)
        XCTAssertLessThanOrEqual(score, 1.0)
    }

    func testRecommendations_noRouter() throws {
        let devices = [
            ThreadDevice(
                name: "Bulb",
                manufacturer: "Test",
                productName: "B",
                deviceType: "Lightbulb",
                uniqueIdentifier: "b1",
                isRouter: false,
                isBorderRouter: false
            )
        ]
        let recs = SignalExtrapolator.recommendations(for: devices)
        XCTAssertTrue(recs.contains { $0.contains("Border router") })
    }
}
