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

    @ObservationIgnored private let maxReadings = 60   // 5 min at 5-second interval
    @ObservationIgnored private let storeURL: URL = {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("device_stats.json")
    }()
    @ObservationIgnored private var persistTask: Task<Void, Never>?

    private init() { restore() }

    func record(deviceName: String, rssi: Int) {
        var list = readings[deviceName, default: []]
        list.append(Reading(timestamp: Date(), rssi: rssi))
        if list.count > maxReadings { list.removeFirst(list.count - maxReadings) }
        readings[deviceName] = list
        schedulePersist()
    }

    func stats(for deviceName: String) -> DeviceStats? {
        guard let list = readings[deviceName], !list.isEmpty else { return nil }
        let values = list.map(\.rssi)
        return DeviceStats(
            readings: list,
            minRSSI: values.min()!,
            maxRSSI: values.max()!,
            avgRSSI: values.reduce(0, +) / values.count
        )
    }

    func clear(for deviceName: String) {
        readings.removeValue(forKey: deviceName)
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
        try? data.write(to: storeURL, options: .atomic)
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
        let total = Double(readings.count)
        guard total > 0 else { return [] }
        let tiers: [(String, Color, (Int) -> Bool)] = [
            ("Excellent", .green,  { $0 > -50 }),
            ("Good",      .mint,   { $0 > -65 && $0 <= -50 }),
            ("Fair",      .orange, { $0 > -80 && $0 <= -65 }),
            ("Weak",      .red,    { $0 <= -80 }),
        ]
        return tiers.map { label, color, pred in
            let count = readings.filter { pred($0.rssi) }.count
            return QualityBucket(label: label, color: color, fraction: Double(count) / total)
        }
    }

    // % of readings at Good or better
    var stabilityPct: Int {
        let good = readings.filter { $0.rssi > -65 }.count
        return readings.isEmpty ? 0 : Int(Double(good) / Double(readings.count) * 100)
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
