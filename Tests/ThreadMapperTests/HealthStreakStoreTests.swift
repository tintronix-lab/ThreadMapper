import XCTest
@testable import ThreadMapper

@MainActor
final class HealthStreakStoreTests: XCTestCase {

    private let cal = Calendar.current

    private func days(from store: HealthStreakStore) -> (Int, Int, Int) {
        (store.currentStreak, store.longestStreak, store.totalADays)
    }

    private func day(_ offset: Int) -> Date {
        cal.date(byAdding: .day, value: offset, to: cal.startOfDay(for: Date()))!
    }

    func testConsecutiveGradeADaysBuildStreak() {
        let store = HealthStreakStore.makeTestInstance()
        store.record(grade: "A", on: day(0))
        store.record(grade: "A", on: day(1))
        store.record(grade: "A", on: day(2))
        XCTAssertEqual(days(from: store).0, 3)   // current
        XCTAssertEqual(days(from: store).1, 3)   // longest
        XCTAssertEqual(days(from: store).2, 3)   // total A days
    }

    func testNonADayResetsStreakButKeepsLongest() {
        let store = HealthStreakStore.makeTestInstance()
        store.record(grade: "A", on: day(0))
        store.record(grade: "A", on: day(1))
        store.record(grade: "B", on: day(2))
        XCTAssertEqual(store.currentStreak, 0)
        XCTAssertEqual(store.longestStreak, 2)
        XCTAssertEqual(store.totalADays, 2)
    }

    func testMissedDayResetsStreakToOne() {
        let store = HealthStreakStore.makeTestInstance()
        store.record(grade: "A", on: day(0))
        store.record(grade: "A", on: day(2))   // gap: day 1 missed
        XCTAssertEqual(store.currentStreak, 1)
        XCTAssertEqual(store.totalADays, 2)
    }

    func testRecordsOnlyOncePerCalendarDay() {
        let store = HealthStreakStore.makeTestInstance()
        store.record(grade: "A", on: day(0))
        store.record(grade: "A", on: day(0).addingTimeInterval(3600))   // same day, later
        XCTAssertEqual(store.currentStreak, 1)
        XCTAssertEqual(store.totalADays, 1)
    }

    func testPersistenceRoundTrip() {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(UUID().uuidString)_streaks.json")
        let store = HealthStreakStore(storeURL: url)
        store.record(grade: "A", on: day(0))
        store.record(grade: "A", on: day(1))
        // A fresh store over the same file restores the streak.
        let reloaded = HealthStreakStore(storeURL: url)
        XCTAssertEqual(reloaded.currentStreak, 2)
        XCTAssertEqual(reloaded.totalADays, 2)
    }
}
