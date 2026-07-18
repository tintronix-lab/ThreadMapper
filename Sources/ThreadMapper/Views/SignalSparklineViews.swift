import SwiftUI

// MARK: - Sparkline view

struct SignalSparklineView: View {
    let readings: [DeviceStatsStore.Reading]
    @ScaledMetric(relativeTo: .caption2) private var sparklineLabelSize: CGFloat = 7

    var body: some View {
        Canvas { ctx, size in
            draw(ctx: &ctx, size: size)
        }
        .background(
            Color(UIColor.tertiarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: 6)
        )
        .accessibilityLabel(Text("Signal history chart"))
        .accessibilityValue(accessibilitySummary)
    }

    private var accessibilitySummary: Text {
        guard let last = readings.last else { return Text("No readings yet") }
        let values = readings.map(\.rssi)
        let lo = values.min() ?? last.rssi
        let hi = values.max() ?? last.rssi
        return Text("Latest \(last.rssi) dBm, \(last.rssi.rssiQualityLabel). ^[\(readings.count) reading](inflect: true), ranging \(lo) to \(hi) dBm.")
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
                let txt = ctx.resolve(Text(label).font(.system(size: sparklineLabelSize)).foregroundStyle(color.opacity(0.8)))
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
            let txt = ctx.resolve(Text(label).font(.system(size: sparklineLabelSize)).foregroundStyle(Color.secondary))
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
        if rssi > SignalThresholds.excellent { return .green }
        if rssi > SignalThresholds.good { return .mint }
        if rssi > SignalThresholds.weak { return .orange }
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
