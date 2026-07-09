import SwiftUI
import Observation

// MARK: - Store

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
        return DeviceStats(
            readings: list,
            minRSSI: values.min()!,
            maxRSSI: values.max()!,
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

    private func persist() {
        struct Payload: Codable { var entries: [String: [Reading]] }
        guard let data = try? JSONEncoder().encode(Payload(entries: readings)) else { return }
        try? data.write(to: storeURL, options: [.atomic, .completeFileProtection])
    }

    private func restore() {
        struct Payload: Codable { var entries: [String: [Reading]] }
        guard let data = try? Data(contentsOf: storeURL),
              let payload = try? JSONDecoder().decode(Payload.self, from: data) else { return }
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
            if      r.rssi > -50 { excellent += 1 }
            else if r.rssi > -65 { good += 1 }
            else if r.rssi > -80 { fair += 1 }
            else                  { weak += 1 }
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

// MARK: - Sparkline view

struct SignalSparklineView: View {
    let readings: [DeviceStatsStore.Reading]

    var body: some View {
        Canvas { ctx, size in
            draw(ctx: &ctx, size: size)
        }
        .background(
            Color(UIColor.tertiarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: 6)
        )
    }

    private func draw(ctx: inout GraphicsContext, size: CGSize) {
        guard readings.count > 1 else { return }

        let rssiLow: Double = -100
        let rssiHigh: Double = -40
        let span = rssiHigh - rssiLow

        func yPos(_ rssi: Int) -> CGFloat {
            CGFloat(1 - (Double(rssi) - rssiLow) / span) * size.height
        }
        func xPos(_ i: Int) -> CGFloat {
            CGFloat(i) / CGFloat(readings.count - 1) * size.width
        }

        // Zone background stripes
        let zones: [(Int, Int, Color)] = [(-40, -50, .green), (-50, -65, .mint),
                                           (-65, -80, .orange), (-80, -100, .red)]
        for (hi, lo, color) in zones {
            let top = yPos(hi), bot = yPos(lo)
            ctx.fill(Path(CGRect(x: 0, y: top, width: size.width, height: bot - top)),
                     with: .color(color.opacity(0.07)))
        }

        // p50 / p95 reference lines
        if readings.count >= 5 {
            let sortedRSSIs = readings.map(\.rssi).sorted()
            let p50 = sortedRSSIs[sortedRSSIs.count / 2]
            let p95 = sortedRSSIs[min(sortedRSSIs.count - 1, sortedRSSIs.count * 95 / 100)]
            for (value, label, color) in [(p50, "p50", Color.blue), (p95, "p95", Color.orange)] {
                let yVal = yPos(value)
                var ln = Path()
                ln.move(to: CGPoint(x: 22, y: yVal))
                ln.addLine(to: CGPoint(x: size.width, y: yVal))
                ctx.stroke(ln, with: .color(color.opacity(0.55)),
                           style: StrokeStyle(lineWidth: 1.0, dash: [4, 3]))
                let txt = ctx.resolve(Text(label).font(.system(size: 7)).foregroundStyle(color.opacity(0.8)))
                ctx.draw(txt, at: CGPoint(x: 10, y: yVal - 4))
            }
        }

        // Threshold dashed lines
        for (thresh, color) in [(-50, Color.green), (-65, Color.orange), (-80, Color.red)] {
            let yT = yPos(thresh)
            var p = Path()
            p.move(to: CGPoint(x: 0, y: yT))
            p.addLine(to: CGPoint(x: size.width, y: yT))
            ctx.stroke(p, with: .color(color.opacity(0.3)),
                       style: StrokeStyle(lineWidth: 0.5, dash: [3, 3]))
        }

        // Y-axis labels
        for (thresh, label) in [(-50, "-50"), (-65, "-65"), (-80, "-80")] {
            let yT = yPos(thresh)
            let txt = ctx.resolve(Text(label).font(.system(size: 7)).foregroundStyle(Color.secondary))
            ctx.draw(txt, at: CGPoint(x: 14, y: yT - 4))
        }

        // Filled area under the line
        var fill = Path()
        for (i, r) in readings.enumerated() {
            let pt = CGPoint(x: xPos(i), y: yPos(r.rssi))
            if i == 0 { fill.move(to: pt) } else { fill.addLine(to: pt) }
        }
        fill.addLine(to: CGPoint(x: size.width, y: size.height))
        fill.addLine(to: CGPoint(x: 0, y: size.height))
        fill.closeSubpath()
        ctx.fill(fill, with: .color(.blue.opacity(0.06)))

        // Segmented line, colored by signal quality
        for i in 1..<readings.count {
            let prev = CGPoint(x: xPos(i - 1), y: yPos(readings[i - 1].rssi))
            let curr = CGPoint(x: xPos(i),     y: yPos(readings[i].rssi))
            var seg = Path(); seg.move(to: prev); seg.addLine(to: curr)
            ctx.stroke(seg, with: .color(lineColor(readings[i].rssi).opacity(0.9)),
                       style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
        }

        // Current-value dot
        if let last = readings.last {
            let pt = CGPoint(x: xPos(readings.count - 1), y: yPos(last.rssi))
            ctx.fill(Path(ellipseIn: CGRect(x: pt.x - 3, y: pt.y - 3, width: 6, height: 6)),
                     with: .color(lineColor(last.rssi)))
        }
    }

    private func lineColor(_ rssi: Int) -> Color {
        if rssi > -50 { return .green }
        if rssi > -65 { return .mint }
        if rssi > -80 { return .orange }
        return .red
    }
}

// MARK: - Quality distribution bar

struct SignalQualityBarView: View {
    let buckets: [DeviceStats.QualityBucket]

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 2) {
                ForEach(Array(buckets.enumerated()), id: \.offset) { _, bucket in
                    if bucket.fraction > 0.005 {
                        bucket.color
                            .opacity(0.75)
                            .frame(width: max(2, geo.size.width * CGFloat(bucket.fraction) - 2))
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                    }
                }
            }
        }
    }
}
