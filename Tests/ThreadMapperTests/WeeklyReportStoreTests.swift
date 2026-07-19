import XCTest
@testable import ThreadMapper

@MainActor
final class WeeklyReportStoreTests: XCTestCase {

    // MARK: - Helpers

    private func makeHistory(scores: [Int], grade: String = "B", spacing: TimeInterval = 400) -> [HealthHistoryStore.Entry] {
        scores.enumerated().map { i, score in
            HealthHistoryStore.Entry(
                timestamp: Date().addingTimeInterval(-Double(scores.count - i) * spacing),
                score: score, grade: grade)
        }
    }

    private func makeOfflineEvent(deviceName: String, daysAgo: Double = 1) -> ActivityEvent {
        ActivityEvent(id: UUID(), timestamp: Date().addingTimeInterval(-daysAgo * 86400),
                      kind: .deviceOffline, deviceID: nil, deviceName: deviceName,
                      room: nil, detail: "went offline")
    }

    // MARK: - Body content

    func testBodyIncludesAverageAndPeakGrade() {
        let entries = makeHistory(scores: [80, 90, 85])
        let report = WeeklyReportStore.generate(
            historyEntries: entries, activityEvents: [],
            currentStreak: 0, totalADays: 0)

        XCTAssertTrue(report.body.contains("/100"), "body should mention average score")
        XCTAssertTrue(report.body.contains("Grade"), "body should mention peak grade")
        XCTAssertEqual(report.avgScore, 85)
    }

    func testBodyMentionsNoOfflineEventsWhenClean() {
        let report = WeeklyReportStore.generate(
            historyEntries: [], activityEvents: [],
            currentStreak: 0, totalADays: 0)

        XCTAssertTrue(report.body.contains("No offline events"))
    }

    func testBodyNamesMostProblematicDevice() {
        let events = [
            makeOfflineEvent(deviceName: "Lamp"),
            makeOfflineEvent(deviceName: "Lamp"),
            makeOfflineEvent(deviceName: "Hub"),
        ]
        let report = WeeklyReportStore.generate(
            historyEntries: [], activityEvents: events,
            currentStreak: 0, totalADays: 0)

        XCTAssertEqual(report.mostProblematicDevice, "Lamp")
        XCTAssertTrue(report.body.contains("Lamp"))
        XCTAssertEqual(report.offlineEventCount, 3)
    }

    func testBodyMentionsStreakWhenThreeOrMore() {
        let report = WeeklyReportStore.generate(
            historyEntries: [], activityEvents: [],
            currentStreak: 5, totalADays: 5)

        XCTAssertTrue(report.body.contains("5-day"))
        XCTAssertEqual(report.streakDays, 5)
    }

    func testBodyMentionsTotalADaysWhenNoStreak() {
        let report = WeeklyReportStore.generate(
            historyEntries: [], activityEvents: [],
            currentStreak: 1, totalADays: 4)

        XCTAssertTrue(report.body.contains("4 days total") || report.body.contains("4 day"))
        XCTAssertEqual(report.totalADays, 4)
    }

    func testBodyNotesTrendImprovement() {
        let entries = makeHistory(scores: [60, 70, 85])
        let report = WeeklyReportStore.generate(
            historyEntries: entries, activityEvents: [],
            currentStreak: 0, totalADays: 0)

        let delta = 85 - 60   // 25 pts
        XCTAssertTrue(report.body.contains("improved \(delta) pts"))
    }

    func testBodyNotesTrendDrop() {
        let entries = makeHistory(scores: [90, 80, 65])
        let report = WeeklyReportStore.generate(
            historyEntries: entries, activityEvents: [],
            currentStreak: 0, totalADays: 0)

        let drop = 90 - 65   // 25 pts
        XCTAssertTrue(report.body.contains("dropped \(drop) pts"))
    }

    // MARK: - Report fields

    func testOfflineEventsOutsideSevenDaysAreExcluded() {
        let stale = ActivityEvent(
            id: UUID(), timestamp: Date().addingTimeInterval(-8 * 86400),
            kind: .deviceOffline, deviceID: nil, deviceName: "OldHub",
            room: nil, detail: "stale")
        let report = WeeklyReportStore.generate(
            historyEntries: [], activityEvents: [stale],
            currentStreak: 0, totalADays: 0)

        XCTAssertEqual(report.offlineEventCount, 0)
        XCTAssertNil(report.mostProblematicDevice)
        XCTAssertTrue(report.body.contains("No offline events"))
    }

    func testHistoryEntriesOutsideSevenDaysAreExcluded() {
        // The history store retains 30 days; the weekly report must ignore
        // anything older than 7. A score-0 entry 10 days back must not drag
        // the average down or register as the lowest grade.
        let stale = HealthHistoryStore.Entry(
            timestamp: Date().addingTimeInterval(-10 * 86400), score: 0, grade: "F")
        let entries = [stale] + makeHistory(scores: [80, 90, 85])
        let report = WeeklyReportStore.generate(
            historyEntries: entries, activityEvents: [],
            currentStreak: 0, totalADays: 0)

        XCTAssertEqual(report.avgScore, 85)
        XCTAssertEqual(report.lowestGrade, "B", "stale grade should not register as lowest")
        XCTAssertNil(report.gradeDistribution["F"])
    }

    func testNowParameterDrivesWeekLabel() {
        // Use noon UTC on Jan 15 to avoid timezone-boundary "Dec" / "Feb" edge cases.
        let anchor = Date(timeIntervalSinceReferenceDate: 86400 * 14 + 43200) // 2001-01-15 12:00 UTC
        let report = WeeklyReportStore.generate(
            historyEntries: [], activityEvents: [],
            currentStreak: 0, totalADays: 0, now: anchor)

        XCTAssertTrue(report.weekRangeLabel.contains(" – "), "label should be a date range")
        XCTAssertEqual(report.generatedAt, anchor)
    }

    // MARK: - generateIfNeeded cooldown and persistence

    func testGenerateIfNeededCreatesReportWhenNoneExists() {
        let store = WeeklyReportStore.makeTestInstance()
        XCTAssertNil(store.latestReport)

        store.generateIfNeeded()

        XCTAssertNotNil(store.latestReport)
    }

    func testGenerateIfNeededSkipsWhenReportIsWithin23Hours() {
        let store = WeeklyReportStore.makeTestInstance()
        let t1 = Date()
        store.generateIfNeeded(now: t1)
        let firstID = store.latestReport?.id

        let t2 = t1.addingTimeInterval(22 * 3600)   // 22 h later — still within window
        store.generateIfNeeded(now: t2)

        XCTAssertEqual(store.latestReport?.id, firstID, "report should not be replaced within 23 h")
    }

    func testGenerateIfNeededReplacesStaleReport() {
        let store = WeeklyReportStore.makeTestInstance()
        let t1 = Date()
        store.generateIfNeeded(now: t1)
        let firstID = store.latestReport?.id

        let t2 = t1.addingTimeInterval(25 * 3600)   // 25 h later — past cooldown
        store.generateIfNeeded(now: t2)

        XCTAssertNotEqual(store.latestReport?.id, firstID, "stale report should be replaced")
        XCTAssertEqual(store.latestReport?.generatedAt, t2)
    }

    func testGenerateIfNeededPersistsAcrossRestart() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(UUID().uuidString)_wr.json")
        let store = WeeklyReportStore(storeURL: url)
        store.generateIfNeeded()
        let id = try XCTUnwrap(store.latestReport?.id)
        await PersistedStore.flush()   // writes land on a background actor

        let reloaded = WeeklyReportStore(storeURL: url)
        XCTAssertEqual(reloaded.latestReport?.id, id)
    }
}
