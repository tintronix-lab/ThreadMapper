import Foundation
import Observation

@MainActor
@Observable
final class HealthStreakStore {
    static let shared = HealthStreakStore()

    private(set) var currentStreak: Int = 0
    private(set) var longestStreak: Int = 0
    private(set) var totalADays: Int = 0

    private struct Persistence: Codable {
        var currentStreak: Int
        var longestStreak: Int
        var totalADays: Int
        var lastRecordedDate: Date?
    }

    @ObservationIgnored private var lastRecordedDate: Date?
    @ObservationIgnored private let storeURL: URL

    /// `storeURL` is injectable so tests can use a throwaway file; the shared
    /// instance persists to Documents.
    init(storeURL: URL? = nil) {
        self.storeURL = storeURL ?? FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("health_streaks.json")
        restore()
    }

    /// Creates a fresh isolated store backed by a temp file. For tests only.
    static func makeTestInstance() -> HealthStreakStore {
        HealthStreakStore(storeURL: FileManager.default.temporaryDirectory
            .appendingPathComponent("\(UUID().uuidString)_streaks.json"))
    }

    /// Records the network grade for the given day (default today). Safe to call
    /// on every poll tick — records once per calendar day and ignores subsequent
    /// same-day calls. `date` is injectable for deterministic tests.
    func record(grade: String, on date: Date = Date()) {
        let today = Calendar.current.startOfDay(for: date)
        if let last = lastRecordedDate, Calendar.current.isDate(last, inSameDayAs: today) { return }

        if grade == "A" {
            let isConsecutive: Bool = {
                guard let last = lastRecordedDate,
                      let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)
                else { return false }
                return Calendar.current.isDate(last, inSameDayAs: yesterday)
            }()
            currentStreak = isConsecutive ? currentStreak + 1 : 1
            longestStreak = max(longestStreak, currentStreak)
            totalADays += 1
            if currentStreak >= 3 { AchievementStore.shared.unlock("streak3") }
            if currentStreak >= 7 { AchievementStore.shared.unlock("streak7") }
        } else {
            currentStreak = 0
        }

        lastRecordedDate = today
        persist()
    }

    private func persist() {
        let p = Persistence(
            currentStreak: currentStreak,
            longestStreak: longestStreak,
            totalADays: totalADays,
            lastRecordedDate: lastRecordedDate
        )
        guard let data = try? JSONEncoder().encode(p) else { return }
        try? data.write(to: storeURL, options: [.atomic, .completeFileProtection])
    }

    private func restore() {
        guard let data = try? Data(contentsOf: storeURL),
              let p = try? JSONDecoder().decode(Persistence.self, from: data) else { return }
        currentStreak = p.currentStreak
        longestStreak = p.longestStreak
        totalADays = p.totalADays
        lastRecordedDate = p.lastRecordedDate
    }
}
