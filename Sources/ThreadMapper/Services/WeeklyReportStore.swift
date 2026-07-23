import Foundation
import Observation

@MainActor
@Observable
final class WeeklyReportStore {
    static let shared = WeeklyReportStore()

    /// Which statements the report chose to make, independent of how they are
    /// phrased. `body` is built from `String(localized:)` prose, so it differs
    /// per locale and cannot be asserted on; these segments are the stable,
    /// testable record of the report's content decisions.
    enum BodySegment: String, Codable {
        case average
        case noOfflineEvents
        case worstDevice
        case borderRouterEvents
        case streak
        case totalADays
        case improved
        case dropped
        case noData
    }

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
        /// Offline-event count attributed to `mostProblematicDevice`.
        let mostProblematicDeviceEventCount: Int
        let streakDays: Int
        let totalADays: Int
        let gradeDistribution: [String: Int] // grade → entry count (5-min intervals)
        let body: String
        /// Locale-independent record of which statements `body` contains.
        let bodySegments: [BodySegment]

        // Backward-compatible decoder: old JSON files lack the new fields.
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            id                     = try c.decode(UUID.self, forKey: .id)
            generatedAt            = try c.decode(Date.self, forKey: .generatedAt)
            weekRangeLabel         = try c.decode(String.self, forKey: .weekRangeLabel)
            avgScore               = try c.decode(Int.self, forKey: .avgScore)
            peakGrade              = try c.decode(String.self, forKey: .peakGrade)
            lowestGrade            = try c.decodeIfPresent(String.self, forKey: .lowestGrade)            ?? "—"
            scoreDelta             = try c.decodeIfPresent(Int.self, forKey: .scoreDelta)             ?? 0
            offlineEventCount      = try c.decode(Int.self, forKey: .offlineEventCount)
            borderRouterEventCount = try c.decodeIfPresent(Int.self, forKey: .borderRouterEventCount) ?? 0
            mostProblematicDevice  = try c.decodeIfPresent(String.self, forKey: .mostProblematicDevice)
            mostProblematicDeviceEventCount = try c.decodeIfPresent(Int.self, forKey: .mostProblematicDeviceEventCount) ?? 0
            streakDays             = try c.decode(Int.self, forKey: .streakDays)
            totalADays             = try c.decode(Int.self, forKey: .totalADays)
            gradeDistribution      = try c.decodeIfPresent([String: Int].self, forKey: .gradeDistribution)   ?? [:]
            body                   = try c.decode(String.self, forKey: .body)
            bodySegments           = try c.decodeIfPresent([BodySegment].self, forKey: .bodySegments)        ?? []
        }

        init(id: UUID, generatedAt: Date, weekRangeLabel: String, avgScore: Int,
             peakGrade: String, lowestGrade: String, scoreDelta: Int,
             offlineEventCount: Int, borderRouterEventCount: Int,
             mostProblematicDevice: String?, mostProblematicDeviceEventCount: Int,
             streakDays: Int, totalADays: Int,
             gradeDistribution: [String: Int], body: String, bodySegments: [BodySegment]) {
            self.id = id; self.generatedAt = generatedAt; self.weekRangeLabel = weekRangeLabel
            self.avgScore = avgScore; self.peakGrade = peakGrade; self.lowestGrade = lowestGrade
            self.scoreDelta = scoreDelta; self.offlineEventCount = offlineEventCount
            self.borderRouterEventCount = borderRouterEventCount
            self.mostProblematicDevice = mostProblematicDevice
            self.mostProblematicDeviceEventCount = mostProblematicDeviceEventCount
            self.streakDays = streakDays; self.totalADays = totalADays
            self.gradeDistribution = gradeDistribution
            self.body = body; self.bodySegments = bodySegments
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

        // The history store retains 30 days; a weekly report must only look at 7.
        let historyEntries = historyEntries.filter { $0.timestamp > sevenDaysAgo }

        // Score stats
        let avgScore = historyEntries.isEmpty ? 0
            : historyEntries.map(\.score).reduce(0, +) / historyEntries.count
        let peakGrade  = historyEntries.max(by: { $0.score < $1.score })?.grade ?? "—"
        let lowestGrade = historyEntries.min(by: { $0.score < $1.score })?.grade ?? "—"
        let scoreDelta: Int = {
            guard let first = historyEntries.first, let last = historyEntries.last,
                  historyEntries.count >= 2 else { return 0 }
            return last.score - first.score
        }()

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

        let worstDeviceCount = worstDevice.map { deviceCounts[$0] ?? 0 } ?? 0

        // Decide *what* the report says, then render it. Segments are recorded
        // on the Report so the decisions stay assertable without depending on
        // the rendered locale.
        var segments: [BodySegment] = []
        if !historyEntries.isEmpty { segments.append(.average) }
        if offlineEvents.isEmpty {
            segments.append(.noOfflineEvents)
        } else if worstDevice != nil {
            segments.append(.worstDevice)
        }
        if brEventCount > 0 { segments.append(.borderRouterEvents) }
        if currentStreak >= 3 {
            segments.append(.streak)
        } else if totalADays > 0 {
            segments.append(.totalADays)
        }
        if scoreDelta >= 10 {
            segments.append(.improved)
        } else if scoreDelta <= -10 {
            segments.append(.dropped)
        }
        if segments.isEmpty { segments.append(.noData) }

        let sentences: [String] = segments.map { segment in
            switch segment {
            case .average:
                return String(localized: "Your Thread network averaged \(avgScore)/100 this week, peaking at Grade \(peakGrade).")
            case .noOfflineEvents:
                return String(localized: "No offline events — solid stability all week.")
            case .worstDevice:
                return String(localized: "\(worstDevice ?? "") caused the most disruption with \(worstDeviceCount) offline events.")
            case .borderRouterEvents:
                return String(localized: "\(brEventCount) border router offline events affected whole-mesh connectivity.")
            case .streak:
                return String(localized: "You're on a \(currentStreak)-day Grade A streak — excellent!")
            case .totalADays:
                return String(localized: "You've reached Grade A on \(totalADays) days total.")
            case .improved:
                return String(localized: "Performance improved \(scoreDelta) pts since the start of the window.")
            case .dropped:
                return String(localized: "Performance dropped \(abs(scoreDelta)) pts — check the Issues tab.")
            case .noData:
                return String(localized: "Open the app regularly to build up your network history for richer weekly reports.")
            }
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
            mostProblematicDeviceEventCount: worstDeviceCount,
            streakDays: currentStreak,
            totalADays: totalADays,
            gradeDistribution: gradeDistribution,
            body: sentences.joined(separator: " "),
            bodySegments: segments
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
