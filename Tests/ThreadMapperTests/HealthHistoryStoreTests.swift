import XCTest
@testable import ThreadMapper

@MainActor
final class HealthHistoryStoreTests: XCTestCase {

    func testRecordAppendsEntry() {
        let store = HealthHistoryStore.makeTestInstance()
        store.record(score: 85, grade: "B")

        XCTAssertEqual(store.entries.count, 1)
        XCTAssertEqual(store.entries.first?.score, 85)
        XCTAssertEqual(store.entries.first?.grade, "B")
    }

    func testRecordThrottlesWithinFiveMinutes() {
        let store = HealthHistoryStore.makeTestInstance()
        store.record(score: 90, grade: "A")
        store.record(score: 80, grade: "B")   // within 5 min — should be ignored

        XCTAssertEqual(store.entries.count, 1)
        XCTAssertEqual(store.entries.first?.score, 90)
    }

    func testClearAllEmptiesAndPersists() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(UUID().uuidString)_hh.json")
        let store = HealthHistoryStore(storeURL: url)
        store.record(score: 75, grade: "C")
        XCTAssertFalse(store.entries.isEmpty)

        store.clearAll()
        XCTAssertTrue(store.entries.isEmpty)
        await PersistedStore.flush()   // writes land on a background actor

        let reloaded = HealthHistoryStore(storeURL: url)
        XCTAssertTrue(reloaded.entries.isEmpty)
    }

    func testRestoreDropsEntriesOlderThanSevenDays() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(UUID().uuidString)_hh.json")
        let recent = HealthHistoryStore.Entry(timestamp: Date(), score: 80, grade: "B")
        let stale  = HealthHistoryStore.Entry(
            timestamp: Date().addingTimeInterval(-8 * 86400), score: 50, grade: "D")
        let data = try JSONEncoder().encode([recent, stale])
        try data.write(to: url)

        let store = HealthHistoryStore(storeURL: url)
        XCTAssertEqual(store.entries.count, 1)
        XCTAssertEqual(store.entries.first?.grade, "B")
    }
}
