import Foundation
import Observation

@Observable
final class WeeklyReportStore {
    static let shared = WeeklyReportStore()

    struct Report: Codable, Identifiable {
        let id: UUID
        let generatedAt: Date
        let weekRangeLabel: String  // "Jun 29 – Jul 5"
        let avgScore: Int
        let peakGrade: String
        let offlineEventCount: Int
        let mostProblematicDevice: String?
        let streakDays: Int
        let totalADays: Int
        let body: String
    }

    private(set) var latestReport: Report?

    @ObservationIgnored private let storeURL: URL = {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("weekly_report.json")
    }()

    private init() { restore() }

    /// Generates a new report if more than 23 hours have passed since the last one.
    func generateIfNeeded() {
        if let r = latestReport, Date().timeIntervalSince(r.generatedAt) < 23 * 3600 { return }
        latestReport = generate()
        persist()
        NotificationService.shared.scheduleWeeklyReport()
    }

    func generate() -> Report {
        let sevenDaysAgo = Date().addingTimeInterval(-7 * 86400)
        let fmt = DateFormatter(); fmt.dateFormat = "MMM d"
        let weekLabel = "\(fmt.string(from: sevenDaysAgo)) – \(fmt.string(from: Date()))"

        // Health history (up to 7 days)
        let historyEntries = HealthHistoryStore.shared.entries
        let avgScore = historyEntries.isEmpty ? 0
            : historyEntries.map(\.score).reduce(0, +) / historyEntries.count
        let peakGrade = historyEntries.max(by: { $0.score < $1.score })?.grade ?? "—"

        // Offline events from ActivityStore (7-day window already kept)
        let offlineEvents = ActivityStore.shared.events.filter {
            $0.timestamp > sevenDaysAgo &&
            ($0.kind == .deviceOffline || $0.kind == .borderRouterOffline)
        }
        let deviceCounts = Dictionary(grouping: offlineEvents) { $0.deviceName ?? "Unknown" }
            .mapValues { $0.count }
        let worstDevice = deviceCounts.max(by: { $0.value < $1.value })?.key

        // Streak data
        let streak = HealthStreakStore.shared

        // Build prose
        var sentences: [String] = []
        if !historyEntries.isEmpty {
            sentences.append("Your Thread network averaged \(avgScore)/100 this week, peaking at Grade \(peakGrade).")
        }
        if offlineEvents.isEmpty {
            sentences.append("No offline events — solid stability all week.")
        } else if let device = worstDevice {
            let n = deviceCounts[device] ?? 0
            sentences.append("\(device) caused the most disruption with \(n) offline event\(n == 1 ? "" : "s").")
        }
        if streak.currentStreak >= 3 {
            sentences.append("You're on a \(streak.currentStreak)-day Grade A streak — excellent!")
        } else if streak.totalADays > 0 {
            sentences.append("You've reached Grade A on \(streak.totalADays) day\(streak.totalADays == 1 ? "" : "s") total.")
        }
        if let first = historyEntries.first, let last = historyEntries.last, historyEntries.count >= 2 {
            let delta = last.score - first.score
            if delta >= 10 { sentences.append("Performance improved \(delta) pts since the start of the window.") }
            else if delta <= -10 { sentences.append("Performance dropped \(abs(delta)) pts — check the Issues tab.") }
        }
        if sentences.isEmpty {
            sentences.append("Open the app regularly to build up your network history for richer weekly reports.")
        }

        return Report(
            id: UUID(),
            generatedAt: Date(),
            weekRangeLabel: weekLabel,
            avgScore: avgScore,
            peakGrade: peakGrade,
            offlineEventCount: offlineEvents.count,
            mostProblematicDevice: worstDevice,
            streakDays: streak.currentStreak,
            totalADays: streak.totalADays,
            body: sentences.joined(separator: " ")
        )
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(latestReport) else { return }
        try? data.write(to: storeURL, options: [.atomic, .completeFileProtection])
    }

    private func restore() {
        guard let data = try? Data(contentsOf: storeURL),
              let report = try? JSONDecoder().decode(Report.self, from: data) else { return }
        latestReport = report
    }
}
