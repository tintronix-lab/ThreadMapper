import Foundation

// MARK: - NF-10: Mesh Topology Time-Lapse

// Stores hourly snapshots of device membership + online status.
// Ring buffer: max 720 entries (30 days × 24 h).

struct TimeLapseFrame: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    let deviceSnapshots: [DeviceSnapshot]

    struct DeviceSnapshot: Codable, Identifiable {
        let id: UUID
        let name: String
        let room: String?
        let isOffline: Bool
        let isBorderRouter: Bool
        let rssi: Int?
    }

    var onlineCount: Int { deviceSnapshots.filter { !$0.isOffline }.count }
    var offlineCount: Int { deviceSnapshots.filter(\.isOffline).count }
    var totalCount: Int { deviceSnapshots.count }
}

@MainActor @Observable
final class TopologyTimeLapseStore {
    static let shared = TopologyTimeLapseStore()

    private static let maxFrames = 720
    private static let minIntervalSeconds: TimeInterval = 3000  // ~50 min dedup window

    private(set) var frames: [TimeLapseFrame] = []

    private static var storeURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("topology_timelapse.json")
    }

    init() {
        frames = (try? JSONDecoder().decode([TimeLapseFrame].self,
                    from: (try? Data(contentsOf: Self.storeURL)) ?? Data())) ?? []
    }

    func record(devices: [ThreadDevice]) {
        // Dedup: skip if last frame was recorded within the window
        if let last = frames.last,
           Date().timeIntervalSince(last.timestamp) < Self.minIntervalSeconds { return }

        let snapshots = devices.map { d in
            TimeLapseFrame.DeviceSnapshot(id: d.id, name: d.name, room: d.room,
                                          isOffline: d.isOffline, isBorderRouter: d.isBorderRouter,
                                          rssi: d.rssi)
        }
        var updated = frames
        updated.append(TimeLapseFrame(id: UUID(), timestamp: Date(), deviceSnapshots: snapshots))

        // Trim to ring buffer size
        if updated.count > Self.maxFrames {
            updated = Array(updated.suffix(Self.maxFrames))
        }
        frames = updated
        persist()
    }

    func clear() {
        frames = []
        try? FileManager.default.removeItem(at: Self.storeURL)
    }

    // MARK: - Biggest structural change for AI narration

    func biggestChange() -> (from: TimeLapseFrame, to: TimeLapseFrame)? {
        guard frames.count >= 2 else { return nil }
        var maxDelta = 0
        var result: (TimeLapseFrame, TimeLapseFrame)? = nil
        for i in 0..<frames.count - 1 {
            let a = frames[i]
            let b = frames[i + 1]
            let delta = abs(b.onlineCount - a.onlineCount) + abs(b.totalCount - a.totalCount)
            if delta > maxDelta {
                maxDelta = delta
                result = (a, b)
            }
        }
        return result
    }

    private func persist() {
        let data = try? JSONEncoder().encode(frames)
        try? data?.write(to: Self.storeURL, options: .atomic)
    }
}
