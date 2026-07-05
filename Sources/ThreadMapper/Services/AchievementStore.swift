import Foundation
import Observation

@Observable final class AchievementStore {
    static let shared = AchievementStore()

    struct Achievement: Codable, Identifiable, Equatable {
        let id: String
        let title: String
        let description: String
        let icon: String
        var unlockedAt: Date?
        var isUnlocked: Bool { unlockedAt != nil }
    }

    private(set) var achievements: [Achievement]
    private(set) var recentlyUnlocked: Achievement?

    @ObservationIgnored private let storeURL: URL = {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("achievements.json")
    }()

    static let catalog: [Achievement] = [
        Achievement(id: "firstSurvey",      title: "First Steps",        description: "Complete your first room survey.", icon: "figure.walk"),
        Achievement(id: "surveyThreeRooms", title: "Coverage Champion",  description: "Survey 3 or more rooms.", icon: "house.fill"),
        Achievement(id: "firstGradeA",      title: "Grade A Network",    description: "Achieve a Grade A health score.", icon: "checkmark.seal.fill"),
        Achievement(id: "streak3",          title: "Streak Starter",     description: "Maintain Grade A for 3 consecutive days.", icon: "flame"),
        Achievement(id: "streak7",          title: "Streak Master",      description: "Maintain Grade A for 7 consecutive days.", icon: "flame.fill"),
        Achievement(id: "resilienceA",      title: "Resilient Home",     description: "Achieve an A resilience score.", icon: "shield.checkmark.fill"),
    ]

    private init() {
        achievements = Self.catalog
        restore()
    }

    func unlock(_ id: String) {
        guard let idx = achievements.firstIndex(where: { $0.id == id }),
              !achievements[idx].isUnlocked else { return }
        achievements[idx].unlockedAt = Date()
        recentlyUnlocked = achievements[idx]
        persist()
    }

    func clearRecentlyUnlocked() {
        recentlyUnlocked = nil
    }

    var unlockedCount: Int { achievements.filter(\.isUnlocked).count }

    private func persist() {
        guard let data = try? JSONEncoder().encode(achievements) else { return }
        try? data.write(to: storeURL, options: [.atomic, .completeFileProtection])
    }

    private func restore() {
        guard let data = try? Data(contentsOf: storeURL),
              let saved = try? JSONDecoder().decode([Achievement].self, from: data) else { return }
        let byID = Dictionary(uniqueKeysWithValues: saved.map { ($0.id, $0) })
        achievements = achievements.map { a in
            var updated = a
            updated.unlockedAt = byID[a.id]?.unlockedAt
            return updated
        }
    }
}
