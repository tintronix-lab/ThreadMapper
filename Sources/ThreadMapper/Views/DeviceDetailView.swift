import SwiftUI

struct DeviceDetailView: View {
    let device: ThreadDevice
    @Environment(\.dismiss) private var dismiss
    @Environment(SurveyViewModel.self) private var surveyVM
    @Environment(DeviceStatsStore.self) private var statsStore
    @Environment(DeviceNotesStore.self) private var notesStore
    @State private var noteText = ""
    @State private var isEditingNote = false

    private var stats: DeviceStats? { statsStore.stats(for: device.name) }
    private var surveyPoints: [SurveyPoint] { surveyVM.surveys(for: device.name) }

    var body: some View {
        NavigationStack {
            Form {
                signalSection
                networkSection
                deviceSection
                if device.batteryPercentage != nil { batterySection }
                surveySection
                notesSection
            }
            .navigationTitle(device.name)
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { noteText = notesStore.note(for: device.uniqueIdentifier.uuidString) }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: - Signal Intelligence

    @ViewBuilder
    private var signalSection: some View {
        Section("Signal Intelligence") {
            // Header row: icon + live RSSI + grade
            HStack(spacing: 12) {
                Image(systemName: device.rssi.rssiSystemIcon)
                    .font(.system(size: 26))
                    .foregroundStyle(currentColor)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text(roleLabel)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("\(currentRSSI) dBm")
                        .font(.title3.bold().monospacedDigit())
                        .foregroundStyle(currentColor)
                    Text(currentRSSI.rssiQualityLabel)
                        .font(.caption2)
                        .foregroundStyle(currentColor.opacity(0.8))
                }

                Spacer()

                if let s = stats {
                    VStack(spacing: 0) {
                        Text(s.healthGrade)
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .foregroundStyle(s.healthColor)
                        Text("Grade")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                        Text("\(s.stabilityPct)% stable")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.vertical, 4)

            if let s = stats, s.readingCount > 1 {
                // Sparkline
                SignalSparklineView(readings: s.readings)
                    .frame(height: 90)
                    .padding(.vertical, 2)

                // Stat cells: Live / Avg / Min / Max
                HStack(spacing: 0) {
                    statCell(value: s.latestRSSI, label: "Live", color: s.latestRSSI.rssiColor)
                    Divider().frame(height: 30)
                    statCell(value: s.avgRSSI, label: "Avg", color: s.avgRSSI.rssiColor)
                    Divider().frame(height: 30)
                    statCell(value: s.minRSSI, label: "Min", color: s.minRSSI.rssiColor)
                    Divider().frame(height: 30)
                    statCell(value: s.maxRSSI, label: "Max", color: s.maxRSSI.rssiColor)
                }
                .padding(.vertical, 4)

                // Quality distribution bar
                VStack(alignment: .leading, spacing: 4) {
                    SignalQualityBarView(buckets: s.qualityBuckets)
                        .frame(height: 10)

                    HStack(spacing: 0) {
                        ForEach(s.qualityBuckets.filter { $0.fraction > 0.005 }, id: \.label) { b in
                            HStack(spacing: 2) {
                                Circle().fill(b.color).frame(width: 5, height: 5)
                                Text(String(format: "%d%%", Int(b.fraction * 100)))
                                    .font(.system(size: 8))
                                    .foregroundStyle(b.color)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }

                // Metadata row
                HStack {
                    Text("\(s.readingCount) readings · ~\(samplingSpanLabel(s))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Clear") { statsStore.clear(for: device.name) }
                        .font(.caption2)
                        .foregroundStyle(.red.opacity(0.7))
                }

            } else {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.mini)
                    Text("Collecting readings — check back in a few seconds.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func statCell(value: Int, label: String, color: Color) -> some View {
        VStack(spacing: 1) {
            Text("\(value)")
                .font(.caption.weight(.semibold).monospacedDigit())
                .foregroundStyle(color)
            Text("dBm")
                .font(.system(size: 8))
                .foregroundStyle(.secondary)
            Text(label)
                .font(.system(size: 8))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func samplingSpanLabel(_ s: DeviceStats) -> String {
        guard let first = s.firstSeen, let last = s.lastSeen else { return "—" }
        let mins = Int(last.timeIntervalSince(first) / 60)
        return mins < 1 ? "<1 min" : "\(mins) min"
    }

    // MARK: - Thread Network

    @ViewBuilder
    private var networkSection: some View {
        Section("Thread Network") {
            // Role badges
            HStack(spacing: 6) {
                roleBadge("Border Router", active: device.isBorderRouter, color: .blue)
                roleBadge("Router", active: device.isRouter && !device.isBorderRouter, color: .mint)
                roleBadge("End Device", active: !device.isRouter && !device.isBorderRouter, color: .gray)
            }
            .padding(.vertical, 2)

            if let ch = device.channel {
                LabeledContent("Channel") {
                    Text("Thread CH \(ch)")
                        .font(.caption.monospacedDigit())
                }
            }
            if let parent = device.parentNodeID {
                LabeledContent("Parent Node", value: parent)
            }
            if device.isSleepyEndDevice {
                Label("Sleepy End Device", systemImage: "moon.zzz.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func roleBadge(_ title: String, active: Bool, color: Color) -> some View {
        Text(title)
            .font(.system(size: 10, weight: active ? .semibold : .regular))
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(active ? color.opacity(0.15) : Color.secondary.opacity(0.08), in: Capsule())
            .foregroundStyle(active ? color : Color.secondary)
    }

    // MARK: - Device Identity

    @ViewBuilder
    private var deviceSection: some View {
        Section("Device") {
            if device.manufacturer != "Unknown" && !device.manufacturer.isEmpty {
                LabeledContent("Manufacturer", value: device.manufacturer)
            }
            if device.productName != "Unknown" && !device.productName.isEmpty {
                LabeledContent("Product", value: device.productName)
            }
            LabeledContent("Type", value: device.deviceType)
            if let room = device.room {
                LabeledContent("Room", value: room)
            }
        }
    }

    // MARK: - Battery

    @ViewBuilder
    private var batterySection: some View {
        Section("Battery") {
            if let batt = device.batteryPercentage {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: batt > 50 ? "battery.75" : batt > 20 ? "battery.25" : "battery.0")
                            .foregroundStyle(batt < 20 ? .red : .secondary)
                            .imageScale(.small)
                        Text("\(batt)%")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(batt < 20 ? .red : .primary)
                        if batt < 20 {
                            Text("Low — consider replacing")
                                .font(.caption2)
                                .foregroundStyle(.red)
                        }
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.secondary.opacity(0.15))
                            RoundedRectangle(cornerRadius: 3)
                                .fill(batt < 20 ? Color.red : batt < 50 ? Color.orange : Color.green)
                                .frame(width: geo.size.width * CGFloat(batt) / 100)
                        }
                    }
                    .frame(height: 8)
                }
                .padding(.vertical, 4)
            }
        }
    }

    // MARK: - Survey

    @ViewBuilder
    private var surveySection: some View {
        Section("Survey") {
            let weakCount = surveyPoints.count
            let total = surveyVM.savedPointCount

            // Coverage summary
            if total > 0 {
                HStack(spacing: 12) {
                    surveyStatCell(value: "\(total)", label: "Sessions")
                    Divider().frame(height: 30)
                    surveyStatCell(
                        value: "\(weakCount)",
                        label: "Weak in",
                        color: weakCount > 0 ? .orange : .green
                    )
                    Divider().frame(height: 30)
                    surveyStatCell(
                        value: weakCount > 0 ? String(format: "%.0f%%", Double(weakCount) / Double(total) * 100) : "0%",
                        label: "Weak rate",
                        color: weakCount > 0 ? .orange : .green
                    )
                }
                .padding(.vertical, 2)
            } else {
                Text("No survey sessions recorded yet. Use the Survey tab to walk your space.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            NavigationLink("Survey History") {
                DeviceSurveyHistory(deviceID: device.name)
            }

            if let url = surveyVM.exportCSV(for: device.name) {
                ShareLink("Export CSV for This Device", item: url)
            }
        }
    }

    private func surveyStatCell(value: String, label: String, color: Color = .primary) -> some View {
        VStack(spacing: 1) {
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Notes

    @ViewBuilder
    private var notesSection: some View {
        Section("Notes") {
            TextField("Add a note about this device…", text: $noteText, axis: .vertical)
                .lineLimit(3...6)
                .font(.subheadline)
                .onChange(of: noteText) { _, new in
                    notesStore.setNote(new, for: device.uniqueIdentifier.uuidString)
                }
        }
    }

    // MARK: - Helpers

    private var currentRSSI: Int { stats?.latestRSSI ?? device.rssi ?? -65 }
    private var currentColor: Color { currentRSSI.rssiColor }

    private var roleLabel: String {
        if device.isBorderRouter { return "Border Router" }
        if device.isRouter { return "Router" }
        if device.isSleepyEndDevice { return "Sleepy End Device" }
        return "End Device"
    }
}
