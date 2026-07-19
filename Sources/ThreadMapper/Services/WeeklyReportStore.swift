import Foundation
import Observation

@MainActor
@Observable
final class WeeklyReportStore {
    static let shared = WeeklyReportStore()

    struct Report: Codable, Identifiable {
        let id: UUID
        let generatedAt: Date
        let weekRangeLabel: String
        let avgScore: Int
        let peakGrade: String
        let lowestGrade: String
        let scoreDelta: Int                  // positive = improved over the window
        let offlineEventCount: Int
        let borderRouterEventCount: Int
        let mostProblematicDevice: String?
        let streakDays: Int
        let totalADays: Int
        let gradeDistribution: [String: Int] // grade → entry count (5-min intervals)
        let body: String

        // Backward-compatible decoder: old JSON files lack the new fields.
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            id                     = try c.decode(UUID.self,   forKey: .id)
            generatedAt            = try c.decode(Date.self,   forKey: .generatedAt)
            weekRangeLabel         = try c.decode(String.self, forKey: .weekRangeLabel)
            avgScore               = try c.decode(Int.self,    forKey: .avgScore)
            peakGrade              = try c.decode(String.self, forKey: .peakGrade)
            lowestGrade            = try c.decodeIfPresent(String.self,      forKey: .lowestGrade)            ?? "—"
            scoreDelta             = try c.decodeIfPresent(Int.self,         forKey: .scoreDelta)             ?? 0
            offlineEventCount      = try c.decode(Int.self,    forKey: .offlineEventCount)
            borderRouterEventCount = try c.decodeIfPresent(Int.self,         forKey: .borderRouterEventCount) ?? 0
            mostProblematicDevice  = try c.decodeIfPresent(String.self,      forKey: .mostProblematicDevice)
            streakDays             = try c.decode(Int.self,    forKey: .streakDays)
            totalADays             = try c.decode(Int.self,    forKey: .totalADays)
            gradeDistribution      = try c.decodeIfPresent([String: Int].self, forKey: .gradeDistribution)   ?? [:]
            body                   = try c.decode(String.self, forKey: .body)
        }

        init(id: UUID, generatedAt: Date, weekRangeLabel: String, avgScore: Int,
             peakGrade: String, lowestGrade: String, scoreDelta: Int,
             offlineEventCount: Int, borderRouterEventCount: Int,
             mostProblematicDevice: String?, streakDays: Int, totalADays: Int,
             gradeDistribution: [String: Int], body: String) {
            self.id = id; self.generatedAt = generatedAt; self.weekRangeLabel = weekRangeLabel
            self.avgScore = avgScore; self.peakGrade = peakGrade; self.lowestGrade = lowestGrade
            self.scoreDelta = scoreDelta; self.offlineEventCount = offlineEventCount
            self.borderRouterEventCount = borderRouterEventCount
            self.mostProblematicDevice = mostProblematicDevice
            self.streakDays = streakDays; self.totalADays = totalADays
            self.gradeDistribution = gradeDistribution; self.body = body
        }
    }

    private(set) var latestReport: Report?

    @ObservationIgnored private let storeURL: URL

    init(storeURL: URL? = nil) {
        self.storeURL = storeURL ?? FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("weekly_report.json")
        restore()
    }

    static func makeTestInstance() -> WeeklyReportStore {
        WeeklyReportStore(storeURL: FileManager.default.temporaryDirectory
            .appendingPathComponent("\(UUID().uuidString)_weekly_report.json"))
    }

    func generateIfNeeded(now: Date = Date()) {
        if let r = latestReport, now.timeIntervalSince(r.generatedAt) < 23 * 3600 { return }
        latestReport = Self.generate(
            historyEntries: HealthHistoryStore.shared.entries,
            activityEvents: ActivityStore.shared.events,
            currentStreak: HealthStreakStore.shared.currentStreak,
            totalADays: HealthStreakStore.shared.totalADays,
            now: now
        )
        persist()
        NotificationService.shared.scheduleWeeklyReport()
    }

    func generate() -> Report {
        Self.generate(
            historyEntries: HealthHistoryStore.shared.entries,
            activityEvents: ActivityStore.shared.events,
            currentStreak: HealthStreakStore.shared.currentStreak,
            totalADays: HealthStreakStore.shared.totalADays
        )
    }

    static func generate(
        historyEntries: [HealthHistoryStore.Entry],
        activityEvents: [ActivityEvent],
        currentStreak: Int,
        totalADays: Int,
        now: Date = Date()
    ) -> Report {
        let sevenDaysAgo = now.addingTimeInterval(-7 * 86400)
        let fmt = DateFormatter(); fmt.dateFormat = "MMM d"
        let weekLabel = "\(fmt.string(from: sevenDaysAgo)) – \(fmt.string(from: now))"

        // Score stats
        let avgScore = historyEntries.isEmpty ? 0
            : historyEntries.map(\.score).reduce(0, +) / historyEntries.count
        let peakGrade  = historyEntries.max(by: { $0.score < $1.score })?.grade ?? "—"
        let lowestGrade = historyEntries.min(by: { $0.score < $1.score })?.grade ?? "—"
        let scoreDelta  = historyEntries.count >= 2
            ? (historyEntries.last!.score - historyEntries.first!.score) : 0

        // Grade distribution (entry counts per grade letter)
        let gradeDistribution = Dictionary(grouping: historyEntries) { $0.grade }
            .mapValues { $0.count }

        // Offline events
        let weekEvents = activityEvents.filter { $0.timestamp > sevenDaysAgo }
        let offlineEvents = weekEvents.filter {
            $0.kind == .deviceOffline || $0.kind == .borderRouterOffline
        }
        let brEventCount = offlineEvents.filter { $0.kind == .borderRouterOffline }.count
        let deviceCounts = Dictionary(grouping: offlineEvents) { $0.deviceName ?? "Unknown" }
            .mapValues { $0.count }
        let worstDevice = deviceCounts.max(by: { $0.value < $1.value })?.key

        // Build prose body
        var sentences: [String] = []
        if !historyEntries.isEmpty {
            sentences.append(String(localized: "Your Thread network averaged \(avgScore)/100 this week, peaking at Grade \(peakGrade)."))
        }
        if offlineEvents.isEmpty {
            sentences.append(String(localized: "No offline events — solid stability all week."))
        } else if let device = worstDevice {
            let n = deviceCounts[device] ?? 0
            sentences.append(String(localized: "\(device) caused the most disruption with \(n) offline events."))
        }
        if brEventCount > 0 {
            sentences.append(String(localized: "\(brEventCount) border router offline events affected whole-mesh connectivity."))
        }
        if currentStreak >= 3 {
            sentences.append(String(localized: "You're on a \(currentStreak)-day Grade A streak — excellent!"))
        } else if totalADays > 0 {
            sentences.append(String(localized: "You've reached Grade A on \(totalADays) days total."))
        }
        if scoreDelta >= 10 {
            sentences.append(String(localized: "Performance improved \(scoreDelta) pts since the start of the window."))
        } else if scoreDelta <= -10 {
            sentences.append(String(localized: "Performance dropped \(abs(scoreDelta)) pts — check the Issues tab."))
        }
        if sentences.isEmpty {
            sentences.append(String(localized: "Open the app regularly to build up your network history for richer weekly reports."))
        }

        return Report(
            id: UUID(),
            generatedAt: now,
            weekRangeLabel: weekLabel,
            avgScore: avgScore,
            peakGrade: peakGrade,
            lowestGrade: lowestGrade,
            scoreDelta: scoreDelta,
            offlineEventCount: offlineEvents.count,
            borderRouterEventCount: brEventCount,
            mostProblematicDevice: worstDevice,
            streakDays: currentStreak,
            totalADays: totalADays,
            gradeDistribution: gradeDistribution,
            body: sentences.joined(separator: " ")
        )
    }

    private func persist() {
        guard let report = latestReport else { return }
        PersistedStore.save(report, to: storeURL)
    }

    private func restore() {
        guard let report = PersistedStore.load(Report.self, from: storeURL) else { return }
        latestReport = report
    }
}
