import SwiftUI
import Charts

struct NetworkTimelineView: View {
    @ScaledMetric(relativeTo: .largeTitle) private var heroIconSize: CGFloat = 32
    @ScaledMetric(relativeTo: .caption2) private var axisLabelSize: CGFloat = 9
    @Environment(HealthHistoryStore.self) private var historyStore
    @Environment(ActivityStore.self) private var activityStore

    @State private var selectedRange: TimeRange = .day

    enum TimeRange: String, CaseIterable, Identifiable {
        case hour6 = "6H", day = "24H", week = "7D"
        var id: String { rawValue }

        var seconds: TimeInterval {
            switch self { case .hour6: 6 * 3600; case .day: 24 * 3600; case .week: 7 * 24 * 3600 }
        }
    }

    // MARK: - Computed data

    private var cutoff: Date { Date().addingTimeInterval(-selectedRange.seconds) }

    private var filteredEntries: [HealthHistoryStore.Entry] {
        historyStore.entries.filter { $0.timestamp >= cutoff }
    }

    private var filteredEvents: [ActivityEvent] {
        activityStore.events
            .filter { $0.timestamp >= cutoff }
            .sorted { $0.timestamp < $1.timestamp }
    }

    // Interpolate health score at an arbitrary timestamp
    private func scoreAt(_ timestamp: Date) -> Double? {
        let entries = filteredEntries
        guard !entries.isEmpty else { return nil }
        if timestamp <= entries[0].timestamp { return Double(entries[0].score) }
        if timestamp >= entries[entries.count - 1].timestamp { return Double(entries[entries.count - 1].score) }
        for i in 1..<entries.count {
            if entries[i].timestamp >= timestamp {
                let a = entries[i - 1]
                let b = entries[i]
                let t = timestamp.timeIntervalSince(a.timestamp) / b.timestamp.timeIntervalSince(a.timestamp)
                return Double(a.score) + t * Double(b.score - a.score)
            }
        }
        return Double(entries.last!.score)
    }

    // MARK: - Body

    var body: some View {
        List {
            rangePickerSection
            chartSection
            if !filteredEvents.isEmpty { legendSection }
            eventsSection
        }
        .navigationTitle("Network Timeline")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Range picker

    private var rangePickerSection: some View {
        Section {
            Picker("Time Range", selection: $selectedRange) {
                ForEach(TimeRange.allCases) { r in
                    Text(r.rawValue).tag(r)
                }
            }
            .pickerStyle(.segmented)
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        }
    }

    // MARK: - Chart

    @ViewBuilder
    private var chartSection: some View {
        Section {
            if filteredEntries.count < 2 {
                emptyChartState
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Health Score")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Spacer()
                        if let latest = filteredEntries.last {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(TMStyle.gradeColor(latest.grade))
                                    .frame(width: 6, height: 6)
                                Text("Grade \(latest.grade) · \(latest.score) pts")
                                    .font(.caption2.monospacedDigit())
                                    .foregroundStyle(TMStyle.gradeColor(latest.grade))
                            }
                        }
                    }
                    mainChart
                }
                .padding(.vertical, 4)
            }
        } header: {
            Text("Score History")
        } footer: {
            if filteredEntries.count >= 2 {
                Text("Colored markers show when network events occurred and how much they affected the score.")
                    .font(.caption)
            }
        }
    }

    private var emptyChartState: some View {
        HStack {
            Spacer()
            VStack(spacing: 10) {
                Image(systemName: "chart.xyaxis.line")
                    .font(.system(size: heroIconSize))
                    .foregroundStyle(.tertiary)
                Text("No Score History")
                    .font(.subheadline.weight(.semibold))
                Text("Open the app regularly to build history for this range.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            Spacer()
        }
        .padding(.vertical, 20)
    }

    @ViewBuilder
    private var mainChart: some View {
        let entries = filteredEntries
        let events = filteredEvents

        Chart {
            // Score area fill
            ForEach(entries) { entry in
                AreaMark(
                    x: .value("Time", entry.timestamp),
                    y: .value("Score", entry.score)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.accentColor.opacity(0.18), Color.accentColor.opacity(0)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .interpolationMethod(.catmullRom)
            }

            // Score line
            ForEach(entries) { entry in
                LineMark(
                    x: .value("Time", entry.timestamp),
                    y: .value("Score", entry.score)
                )
                .foregroundStyle(Color.accentColor)
                .lineStyle(StrokeStyle(lineWidth: 2))
                .interpolationMethod(.catmullRom)
            }

            // Event vertical markers + dots
            ForEach(events) { event in
                RuleMark(x: .value("Event", event.timestamp))
                    .foregroundStyle(event.kind.color.opacity(0.35))
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [3, 2]))

                if let score = scoreAt(event.timestamp) {
                    PointMark(
                        x: .value("Event", event.timestamp),
                        y: .value("Score", score)
                    )
                    .foregroundStyle(event.kind.color)
                    .symbolSize(70)
                }
            }
        }
        .chartYScale(domain: 0...100)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3, 3]))
                AxisValueLabel(format: xAxisFormat)
            }
        }
        .chartYAxis {
            AxisMarks(values: [0, 25, 50, 75, 100]) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3, 3]))
                AxisValueLabel {
                    if let v = value.as(Int.self) {
                        Text(verbatim: "\(v)").font(.system(size: axisLabelSize))
                    }
                }
            }
        }
        .frame(height: 170)
        .accessibilityLabel(Text("Network health score timeline"))
        .accessibilityValue(timelineAccessibilitySummary(entries))
    }

    private func timelineAccessibilitySummary(_ entries: [HealthHistoryStore.Entry]) -> Text {
        guard let latest = entries.last else { return Text("No score history") }
        let lo = entries.map(\.score).min() ?? latest.score
        let hi = entries.map(\.score).max() ?? latest.score
        return Text("Latest score \(latest.score), grade \(latest.grade). Ranged \(lo) to \(hi) over ^[\(entries.count) sample](inflect: true).")
    }

    private var xAxisFormat: Date.FormatStyle {
        switch selectedRange {
        case .hour6: return .dateTime.hour().minute()
        case .day:   return .dateTime.hour()
        case .week:  return .dateTime.weekday(.abbreviated).hour()
        }
    }

    // MARK: - Legend

    @ViewBuilder
    private var legendSection: some View {
        let usedKinds = Array(Set(filteredEvents.map(\.kind)))
            .sorted { $0.rawValue < $1.rawValue }

        Section {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(usedKinds, id: \.self) { kind in
                        HStack(spacing: 5) {
                            Circle()
                                .fill(kind.color)
                                .frame(width: 9, height: 9)
                            Text(kind.label)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.vertical, 2)
            }
        } header: {
            Text("Event Legend")
        }
    }

    // MARK: - Events list

    @ViewBuilder
    private var eventsSection: some View {
        let events = filteredEvents.reversed()

        if events.isEmpty {
            Section {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "clock.badge.checkmark")
                            .font(.largeTitle)
                            .foregroundStyle(.tertiary)
                        Text("No Events in This Window")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 16)
                    Spacer()
                }
            } header: { Text("Events") }
        } else {
            Section {
                ForEach(events) { event in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: event.kind.icon)
                            .foregroundStyle(event.kind.color)
                            .imageScale(.small)
                            .frame(width: 18)
                            .padding(.top, 2)

                        VStack(alignment: .leading, spacing: 3) {
                            HStack {
                                Text(event.kind.label)
                                    .font(.subheadline.weight(.semibold))
                                Spacer()
                                if let score = scoreAt(event.timestamp) {
                                    Text("Score \(Int(score))")
                                        .font(.caption2.monospacedDigit())
                                        .foregroundStyle(.secondary)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(.secondary.opacity(0.1), in: Capsule())
                                }
                            }
                            Text(event.detail)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }

                        VStack(alignment: .trailing, spacing: 2) {
                            Text(event.timestamp, style: .relative)
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(.tertiary)
                            Text("ago")
                                .font(.system(size: axisLabelSize))
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .padding(.vertical, 2)
                }
            } header: {
                HStack {
                    Text("Events")
                    Spacer()
                    Text("\(Array(events).count) in window")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            } footer: {
                Text("Score shown is the interpolated health score at the moment each event was recorded.")
                    .font(.caption)
            }
        }
    }
}
