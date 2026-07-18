import XCTest
@testable import ThreadMapper

@MainActor
final class ActivityStoreTests: XCTestCase {

    func testRecordInsertsNewestFirst() {
        let store = ActivityStore.makeTestInstance()
        store.record(kind: .deviceOffline, deviceName: "Lamp", room: "Den", detail: "went offline")
        store.record(kind: .deviceOnline, deviceName: "Lamp", room: "Den", detail: "came back")

        XCTAssertEqual(store.events.count, 2)
        XCTAssertEqual(store.events.first?.kind, .deviceOnline)   // most recent at index 0
        XCTAssertEqual(store.events.last?.kind, .deviceOffline)
    }

    func testRecordCapsAtMaxEvents() {
        let store = ActivityStore.makeTestInstance()
        for i in 0..<520 {
            store.record(kind: .healthImproved, detail: "tick \(i)")
        }
        XCTAssertEqual(store.events.count, 500)
        // The newest record is retained; the oldest overflow is dropped.
        XCTAssertEqual(store.events.first?.detail, "tick 519")
        XCTAssertEqual(store.events.last?.detail, "tick 20")
    }

    func testClearAllEmptiesAndPersists() async {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(UUID().uuidString)_activity.json")
        let store = ActivityStore(storeURL: url)
        store.record(kind: .deviceOffline, detail: "x")
        store.clearAll()
        XCTAssertTrue(store.events.isEmpty)
        await PersistedStore.flush()   // writes land on a background actor

        // A fresh store over the same file restores nothing.
        let reloaded = ActivityStore(storeURL: url)
        XCTAssertTrue(reloaded.events.isEmpty)
    }

    func testRestoreDropsEventsOlderThanSevenDays() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(UUID().uuidString)_activity.json")
        let recent = ActivityEvent(id: UUID(), timestamp: Date(), kind: .deviceOnline,
                                   deviceID: nil, deviceName: nil, room: nil, detail: "recent")
        let stale = ActivityEvent(id: UUID(), timestamp: Date().addingTimeInterval(-8 * 86400),
                                  kind: .deviceOffline, deviceID: nil, deviceName: nil, room: nil, detail: "stale")
        let data = try JSONEncoder().encode([recent, stale])
        try data.write(to: url)

        let store = ActivityStore(storeURL: url)
        XCTAssertEqual(store.events.count, 1)
        XCTAssertEqual(store.events.first?.detail, "recent")
    }
}
