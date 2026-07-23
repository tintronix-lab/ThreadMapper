import CoreLocation
@testable import ThreadMapper
import XCTest

final class SurveyHeatmapPresenterTests: XCTestCase {

    private func point(_ lat: Double, _ lng: Double, rssi: Double, weak: [String] = []) -> SurveyPoint {
        SurveyPoint(coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lng),
                    meanRSSI: rssi, weakDevices: weak)
    }

    func testEmptyPointsYieldNoCells() {
        XCTAssertTrue(SurveyHeatmapPresenter.present(points: []).isEmpty)
    }

    func testSinglePointProducesScoredCellsInRange() {
        let cells = SurveyHeatmapPresenter.present(points: [point(37.0, -122.0, rssi: -60)])
        XCTAssertFalse(cells.isEmpty)   // minimum spread guarantees cells even for one location
        for cell in cells {
            XCTAssertGreaterThanOrEqual(cell.score, 0.0)
            XCTAssertLessThanOrEqual(cell.score, 1.0)
        }
    }

    func testStrongerSignalScoresHigher() {
        let strong = SurveyHeatmapPresenter.present(points: [point(37.0, -122.0, rssi: -50)]).map(\.score).max() ?? 0
        let weak = SurveyHeatmapPresenter.present(points: [point(37.0, -122.0, rssi: -85)]).map(\.score).max() ?? 0
        XCTAssertGreaterThan(strong, weak)
    }

    func testWeakDevicesAreCounted() {
        let cells = SurveyHeatmapPresenter.present(points: [point(37.0, -122.0, rssi: -80, weak: ["Sensor"])])
        XCTAssertTrue(cells.contains { $0.weakDeviceCount > 0 })
    }

    func testWeakSpotsRespectThresholdAndLimit() {
        let cells = (0..<20).map {
            SurveyHeatmapPresenter.Cell(
                coordinate: CLLocationCoordinate2D(latitude: 0, longitude: 0),
                score: Double($0) / 100.0,   // 0.00 … 0.19, all below the threshold
                weakDeviceCount: 0)
        }
        let spots = SurveyHeatmapPresenter.weakSpots(from: cells, threshold: 0.35, limit: 5)
        XCTAssertEqual(spots.count, 5)                          // limit respected
        XCTAssertTrue(spots.allSatisfy { $0.score < 0.35 })     // threshold respected
    }
}
