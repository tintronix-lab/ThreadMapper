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

    func testRestoreDropsEntriesOlderThanThirtyDays() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(UUID().uuidString)_hh.json")
        let recent = HealthHistoryStore.Entry(
            timestamp: Date().addingTimeInterval(-29 * 86400), score: 80, grade: "B")
        let stale  = HealthHistoryStore.Entry(
            timestamp: Date().addingTimeInterval(-31 * 86400), score: 50, grade: "D")
        let data = try JSONEncoder().encode([recent, stale])
        try data.write(to: url)

        let store = HealthHistoryStore(storeURL: url)
        XCTAssertEqual(store.entries.count, 1)
        XCTAssertEqual(store.entries.first?.grade, "B")
    }

    func testDownsampledAveragesScoresPerBucket() {
        let base = Date(timeIntervalSinceReferenceDate: 1_000_000)
        let entries = [
            HealthHistoryStore.Entry(timestamp: base, score: 60, grade: "C"),
            HealthHistoryStore.Entry(timestamp: base.addingTimeInterval(300), score: 80, grade: "B"),
            HealthHistoryStore.Entry(timestamp: base.addingTimeInterval(3600), score: 100, grade: "A"),
        ]

        let result = HealthHistoryStore.downsampled(entries, bucket: 3600)

        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0].score, 70)          // mean of 60 and 80
        XCTAssertEqual(result[0].grade, "B")         // last entry in bucket wins
        XCTAssertEqual(result[1].score, 100)
        XCTAssertEqual(result[1].grade, "A")
    }

    func testDownsampledPassesThroughSmallOrEmptyInput() {
        let single = [HealthHistoryStore.Entry(timestamp: Date(), score: 90, grade: "A")]

        XCTAssertTrue(HealthHistoryStore.downsampled([], bucket: 3600).isEmpty)
        XCTAssertEqual(HealthHistoryStore.downsampled(single, bucket: 3600).count, 1)
        XCTAssertEqual(HealthHistoryStore.downsampled(single, bucket: 3600).first?.score, 90)
    }
}
