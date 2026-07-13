import SwiftUI
import Observation

@MainActor
@Observable
final class HealthHistoryStore {

    struct Entry: Codable, Identifiable {
        let id: UUID
        let timestamp: Date
        let score: Int
        let grade: String

        init(timestamp: Date, score: Int, grade: String) {
            id = UUID()
            self.timestamp = timestamp
            self.score = score
            self.grade = grade
        }

        private enum CodingKeys: String, CodingKey { case id, timestamp, score, grade }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            id = (try? c.decode(UUID.self, forKey: .id)) ?? UUID()
            timestamp = try c.decode(Date.self, forKey: .timestamp)
            score = try c.decode(Int.self, forKey: .score)
            grade = try c.decode(String.self, forKey: .grade)
        }
    }

    static let shared = HealthHistoryStore()

    private(set) var entries: [Entry] = []

    @ObservationIgnored private let maxEntries = 2016  // 7 days at 5-min intervals
    @ObservationIgnored private let storeURL: URL
    @ObservationIgnored private var persistTask: Task<Void, Never>?

    /// `storeURL` is injectable so tests can use a throwaway file; the shared
    /// instance persists to Documents.
    init(storeURL: URL? = nil) {
        self.storeURL = storeURL ?? FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("health_history.json")
        restore()
    }

    /// Creates a fresh isolated store backed by a temp file. For tests only.
    static func makeTestInstance() -> HealthHistoryStore {
        HealthHistoryStore(storeURL: FileManager.default.temporaryDirectory
            .appendingPathComponent("\(UUID().uuidString)_health_history.json"))
    }

    // Throttles to at most one sample per 5 minutes.
    func record(score: Int, grade: String) {
        if let last = entries.last, Date().timeIntervalSince(last.timestamp) < 300 { return }
        entries.append(Entry(timestamp: Date(), score: score, grade: grade))
        if entries.count > maxEntries { entries.removeFirst(entries.count - maxEntries) }
        schedulePersist()
    }

    func clearAll() {
        entries = []
        persist()
    }

    private func schedulePersist() {
        persistTask?.cancel()
        persistTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            self?.persist()
        }
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        try? data.write(to: storeURL, options: [.atomic, .completeFileProtection])
    }

    private func restore() {
        guard let data = try? Data(contentsOf: storeURL),
              let decoded = try? JSONDecoder().decode([Entry].self, from: data) else { return }
        let cutoff = Date().addingTimeInterval(-7 * 86400)
        entries = decoded.filter { $0.timestamp > cutoff }
    }
}
