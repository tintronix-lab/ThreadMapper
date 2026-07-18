import SwiftUI
import Observation

// MARK: - Store

@MainActor
@Observable
final class DeviceStatsStore {

    struct Reading: Codable {
        let timestamp: Date
        let rssi: Int
    }

    static let shared = DeviceStatsStore()

    private(set) var readings: [String: [Reading]] = [:]

    @ObservationIgnored private let maxReadings = 360  // 30 min at 5-second interval
    @ObservationIgnored private let storeURL: URL
    @ObservationIgnored private var persistTask: Task<Void, Never>?

    private init(storeURL: URL? = nil) {
        self.storeURL = storeURL ?? FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("device_stats.json")
        restore()
    }

    /// Creates a fresh isolated store backed by a temp file. For tests only.
    static func makeTestInstance() -> DeviceStatsStore {
        DeviceStatsStore(storeURL: FileManager.default.temporaryDirectory
            .appendingPathComponent("\(UUID().uuidString)_stats.json"))
    }

    func record(deviceID: UUID, rssi: Int) {
        let key = deviceID.uuidString
        var list = readings[key, default: []]
        list.append(Reading(timestamp: Date(), rssi: rssi))
        if list.count > maxReadings { list.removeFirst(list.count - maxReadings) }
        readings[key] = list
        schedulePersist()
    }

    func stats(for deviceID: UUID) -> DeviceStats? {
        guard let list = readings[deviceID.uuidString], !list.isEmpty else { return nil }
        let values = list.map(\.rssi)
        guard let minRSSI = values.min(), let maxRSSI = values.max() else { return nil }
        return DeviceStats(
            readings: list,
            minRSSI: minRSSI,
            maxRSSI: maxRSSI,
            avgRSSI: values.reduce(0, +) / values.count
        )
    }

    /// Returns time-bucketed network-wide average RSSI over the last `minutes` minutes.
    func networkTrendBuckets(minutes: Int = 30, bucketMinutes: Int = 3) -> [(timestamp: Date, avgRSSI: Int)] {
        let now = Date()
        let cutoff = now.addingTimeInterval(-Double(minutes) * 60)
        let bucketSec = Double(bucketMinutes) * 60
        let bucketCount = Int(Double(minutes) * 60 / bucketSec)

        var sums = [Int: Int]()
        var counts = [Int: Int]()

        for deviceReadings in readings.values {
            for r in deviceReadings where r.timestamp > cutoff {
                let idx = Int(now.timeIntervalSince(r.timestamp) / bucketSec)
                guard idx < bucketCount else { continue }
                sums[idx, default: 0] += r.rssi
                counts[idx, default: 0] += 1
            }
        }

        return (0..<bucketCount).compactMap { idx in
            guard let c = counts[idx], c > 0, let s = sums[idx] else { return nil }
            let ts = now.addingTimeInterval(-Double(idx) * bucketSec - bucketSec / 2)
            return (timestamp: ts, avgRSSI: s / c)
        }.sorted { $0.timestamp < $1.timestamp }
    }

    func clear(for deviceID: UUID) {
        readings.removeValue(forKey: deviceID.uuidString)
        persist()
    }

    func clearAll() {
        readings = [:]
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

    private struct Payload: Codable { var entries: [String: [Reading]] }

    private func persist() {
        PersistedStore.save(Payload(entries: readings), to: storeURL)
    }

    private func restore() {
        guard let payload = PersistedStore.load(Payload.self, from: storeURL) else { return }
        // Discard readings older than 1 hour
        let cutoff = Date().addingTimeInterval(-3600)
        readings = payload.entries.mapValues { list in
            list.filter { $0.timestamp > cutoff }
        }.filter { !$0.value.isEmpty }
    }
}

// MARK: - Stats model

struct DeviceStats {
    struct QualityBucket {
        let label: String
        let color: Color
        let fraction: Double
    }

    let readings: [DeviceStatsStore.Reading]
    let minRSSI: Int
    let maxRSSI: Int
    let avgRSSI: Int

    var latestRSSI: Int { readings.last?.rssi ?? avgRSSI }
    var readingCount: Int { readings.count }
    var firstSeen: Date? { readings.first?.timestamp }
    var lastSeen: Date? { readings.last?.timestamp }

    // 0.0 (worst) → 1.0 (best); maps -100…-40 dBm linearly
    var healthScore: Double {
        max(0, min(1, Double(avgRSSI + 100) / 60.0))
    }

    var healthGrade: String {
        switch healthScore {
        case 0.83...: return "A"
        case 0.67..<0.83: return "B"
        case 0.50..<0.67: return "C"
        case 0.33..<0.50: return "D"
        default: return "F"
        }
    }

    var healthColor: Color {
        switch healthGrade {
        case "A": return .green
        case "B": return .mint
        case "C": return .orange
        case "D": return .red
        default: return Color(red: 0.6, green: 0, blue: 0)
        }
    }

    var qualityBuckets: [QualityBucket] {
        guard !readings.isEmpty else { return [] }
        let total = Double(readings.count)
        var excellent = 0, good = 0, fair = 0, weak = 0
        for r in readings {
            if      r.rssi > SignalThresholds.excellent { excellent += 1 }
            else if r.rssi > SignalThresholds.good { good += 1 }
            else if r.rssi > SignalThresholds.weak { fair += 1 }
            else { weak += 1 }
        }
        return [
            QualityBucket(label: "Excellent", color: .green,  fraction: Double(excellent) / total),
            QualityBucket(label: "Good",      color: .mint,   fraction: Double(good) / total),
            QualityBucket(label: "Fair",      color: .orange, fraction: Double(fair) / total),
            QualityBucket(label: "Weak",      color: .red,    fraction: Double(weak) / total),
        ]
    }

    // % of readings at Good or better — derived from qualityBuckets to avoid a fourth pass.
    var stabilityPct: Int {
        guard !readings.isEmpty else { return 0 }
        let buckets = qualityBuckets
        let goodFrac = (buckets.first { $0.label == "Excellent" }?.fraction ?? 0)
                     + (buckets.first { $0.label == "Good" }?.fraction ?? 0)
        return Int(goodFrac * 100)
    }

    // Sort once; reuse for both p50 and p95.
    private var sortedRSSIs: [Int] { readings.map(\.rssi).sorted() }

    var p50: Int {
        guard !readings.isEmpty else { return avgRSSI }
        let s = sortedRSSIs
        return s[s.count / 2]
    }

    var p95: Int {
        guard readings.count >= 5 else { return minRSSI }
        let s = sortedRSSIs
        return s[min(s.count - 1, s.count * 95 / 100)]
    }

    var jitter: Int { p95 - p50 }

    var jitterLabel: String {
        switch jitter {
        case ..<10:  return "Stable"
        case 10..<20: return "Variable"
        default:     return "Erratic"
        }
    }
}
