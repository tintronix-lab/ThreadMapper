import Foundation
import Observation

@Observable
final class ActivityStore {
    static let shared = ActivityStore()

    private(set) var events: [ActivityEvent] = []

    @ObservationIgnored private let maxEvents = 500
    @ObservationIgnored private let storeURL: URL
    @ObservationIgnored private var persistTask: Task<Void, Never>?

    /// `storeURL` is injectable so tests can use a throwaway file; the shared
    /// instance persists to Documents.
    init(storeURL: URL? = nil) {
        self.storeURL = storeURL ?? FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("activity_events.json")
        restore()
    }

    /// Creates a fresh isolated store backed by a temp file. For tests only.
    static func makeTestInstance() -> ActivityStore {
        ActivityStore(storeURL: FileManager.default.temporaryDirectory
            .appendingPathComponent("\(UUID().uuidString)_activity_events.json"))
    }

    func record(kind: ActivityEvent.Kind, deviceID: UUID? = nil, deviceName: String? = nil, room: String? = nil, detail: String) {
        let event = ActivityEvent(id: UUID(), timestamp: Date(), kind: kind,
                                  deviceID: deviceID, deviceName: deviceName, room: room, detail: detail)
        events.insert(event, at: 0)
        if events.count > maxEvents { events = Array(events.prefix(maxEvents)) }
        schedulePersist()
    }

    func clearAll() {
        events = []
        persist()
    }

    // MARK: - Persistence

    private func schedulePersist() {
        persistTask?.cancel()
        persistTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            self?.persist()
        }
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(events) else { return }
        try? data.write(to: storeURL, options: [.atomic, .completeFileProtection])
    }

    private func restore() {
        guard let data = try? Data(contentsOf: storeURL),
              let decoded = try? JSONDecoder().decode([ActivityEvent].self, from: data) else { return }
        let cutoff = Date().addingTimeInterval(-7 * 86400)   // keep 7 days
        events = decoded.filter { $0.timestamp > cutoff }
    }
}
