import Foundation
import Observation

// MARK: - Observation model

struct AIObservation: Codable, Identifiable {
    let id: UUID
    let deviceID: UUID
    let timestamp: Date

    enum Kind: String, Codable {
        case anomalyDetected
        case offlineEvent
        case userResolvedFix

        var label: String {
            switch self {
            case .anomalyDetected: return "Signal anomaly"
            case .offlineEvent:    return "Went offline"
            case .userResolvedFix: return "Fix applied"
            }
        }
    }

    let kind: Kind
    let detail: String
    var isResolved: Bool
}

// MARK: - Store

/// Persists per-device AI observations across sessions to enable self-learning prompts.
/// Observations are injected into AI prompts so the assistant can reference past patterns.
@MainActor
@Observable
final class AIMemoryStore {
    static let shared = AIMemoryStore()

    private(set) var observationsByDevice: [UUID: [AIObservation]] = [:]

    @ObservationIgnored private let storeURL: URL
    private static let maxPerDevice = 20
    private static let dedupeWindow: TimeInterval = 600   // 10 min: skip same-kind repeats

    private init(storeURL: URL? = nil) {
        self.storeURL = storeURL ?? Self.defaultURL
        restore()
    }

    // MARK: - Recording

    func record(_ observation: AIObservation) {
        var list = observationsByDevice[observation.deviceID, default: []]
        if let last = list.last,
           last.kind == observation.kind,
           observation.timestamp.timeIntervalSince(last.timestamp) < Self.dedupeWindow { return }
        list.append(observation)
        if list.count > Self.maxPerDevice { list.removeFirst(list.count - Self.maxPerDevice) }
        observationsByDevice[observation.deviceID] = list
        persist()
    }

    func markResolved(_ id: UUID, for deviceID: UUID) {
        guard var list = observationsByDevice[deviceID],
              let idx = list.firstIndex(where: { $0.id == id }) else { return }
        list[idx].isResolved = true
        observationsByDevice[deviceID] = list
        persist()
    }

    func observations(for deviceID: UUID, limit: Int = 5) -> [AIObservation] {
        Array((observationsByDevice[deviceID] ?? []).suffix(limit))
    }

    /// Short text injected into AI prompts describing past observations for a device.
    func summaryPromptFragment(for deviceID: UUID) -> String {
        let obs = observations(for: deviceID, limit: 5)
        guard !obs.isEmpty else { return "" }
        let lines = obs.map { o -> String in
            let ago = Int(Date().timeIntervalSince(o.timestamp) / 3600)
            let resolved = o.isResolved ? " (resolved)" : ""
            return "- \(o.kind.label): \(o.detail)\(resolved) (\(ago)h ago)"
        }
        return "Device history from memory:\n" + lines.joined(separator: "\n")
    }

    /// All devices that have had offline events in the last 30 days, grouped by device ID.
    func recurringOfflineDevices(threshold: Int = 3) -> [UUID: Int] {
        let cutoff = Date().addingTimeInterval(-30 * 24 * 3600)
        var result: [UUID: Int] = [:]
        for (id, obs) in observationsByDevice {
            let count = obs.filter { $0.kind == .offlineEvent && $0.timestamp > cutoff && !$0.isResolved }.count
            if count >= threshold { result[id] = count }
        }
        return result
    }

    // MARK: - Persistence

    private static var defaultURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ai_memory.json")
    }

    private struct Payload: Codable {
        var entries: [String: [AIObservation]]
    }

    private func persist() {
        let stringKeyed = Dictionary(uniqueKeysWithValues:
            observationsByDevice.map { ($0.key.uuidString, $0.value) }
        )
        PersistedStore.save(Payload(entries: stringKeyed), to: storeURL)
    }

    private func restore() {
        guard let payload = PersistedStore.load(Payload.self, from: storeURL) else { return }
        let cutoff = Date().addingTimeInterval(-30 * 24 * 3600)
        observationsByDevice = Dictionary(uniqueKeysWithValues:
            payload.entries.compactMap { kv -> (UUID, [AIObservation])? in
                guard let uuid = UUID(uuidString: kv.key) else { return nil }
                let fresh = kv.value.filter { $0.timestamp > cutoff }
                guard !fresh.isEmpty else { return nil }
                return (uuid, fresh)
            }
        )
    }
}
