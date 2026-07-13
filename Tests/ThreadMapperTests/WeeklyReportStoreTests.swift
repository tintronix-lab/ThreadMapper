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

    func testFallbackBodyWhenNoData() {
        let report = WeeklyReportStore.generate(
            historyEntries: [], activityEvents: [],
            currentStreak: 0, totalADays: 0)

        XCTAssertTrue(report.body.contains("Open the app regularly"))
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

    func testNowParameterDrivesWeekLabel() {
        let anchor = Date(timeIntervalSinceReferenceDate: 0)   // 2001-01-01
        let report = WeeklyReportStore.generate(
            historyEntries: [], activityEvents: [],
            currentStreak: 0, totalADays: 0, now: anchor)

        XCTAssertTrue(report.weekRangeLabel.contains("Jan"))
        XCTAssertEqual(report.generatedAt, anchor)
    }
}
