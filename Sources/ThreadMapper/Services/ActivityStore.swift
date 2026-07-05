import Foundation
import Observation

@Observable
final class ActivityStore {
    static let shared = ActivityStore()

    private(set) var events: [ActivityEvent] = []

    @ObservationIgnored private let maxEvents = 500
    @ObservationIgnored private let storeURL: URL = {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("activity_events.json")
    }()
    @ObservationIgnored private var persistTask: Task<Void, Never>?

    private init() { restore() }

    func record(kind: ActivityEvent.Kind, deviceName: String? = nil, room: String? = nil, detail: String) {
        let event = ActivityEvent(id: UUID(), timestamp: Date(), kind: kind,
                                  deviceName: deviceName, room: room, detail: detail)
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
        try? data.write(to: storeURL, options: .atomic)
    }

    private func restore() {
        guard let data = try? Data(contentsOf: storeURL),
              let decoded = try? JSONDecoder().decode([ActivityEvent].self, from: data) else { return }
        let cutoff = Date().addingTimeInterval(-7 * 86400)   // keep 7 days
        events = decoded.filter { $0.timestamp > cutoff }
    }
}
