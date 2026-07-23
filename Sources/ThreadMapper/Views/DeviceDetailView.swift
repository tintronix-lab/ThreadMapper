import SwiftUI

struct DeviceDetailView: View {
    let device: ThreadDevice
    @Environment(\.dismiss) private var dismiss
    @Environment(MeshViewModel.self) var meshViewModel
    @Environment(ActivityStore.self) private var activityStore
    @Environment(SurveyViewModel.self) private var surveyVM
    @Environment(DeviceStatsStore.self) private var statsStore
    @Environment(DeviceNotesStore.self) private var notesStore
    @State private var noteText = ""
    @State private var isEditingNote = false
    @Environment(DeviceOverrideStore.self) private var overrideStore
    @State private var troubleshootProblem: TroubleshooterView.Problem? = nil
    // Generated once on appear — generating in body wrote a temp file on every render.
    @State private var exportURL: URL?
    @State private var showFirmwareHistory = false
    @State private var showAIAssistant = false
    @State private var showPaywall = false
    @State private var deviceAISummary: String? = nil
    @State private var isLoadingDeviceSummary = false
    @State private var explainContext: MetricExplanationContext? = nil
    @State private var metricExplanation: String? = nil
    @State private var isLoadingMetricExplanation = false

    struct MetricExplanationContext: Identifiable {
        let id = UUID()
        let metricName: String
        let displayValue: String
        let aiPromptContext: String
    }

    struct HopEntry {
        let name: String
        let kind: MeshNodeKind
        let isCurrentDevice: Bool
    }

    /// Rebuilding the topology graph is O(devices²); cached here and refreshed
    /// by .task(id:) only when the topology-relevant inputs actually change,
    /// instead of on every render of this view.
    @State var meshPath: [HopEntry] = []


    private var stats: DeviceStats? { statsStore.stats(for: device.uniqueIdentifier) }
    private var surveyPoints: [SurveyPoint] { surveyVM.surveys(for: device.name) }
    private var firmwareChanges: [FirmwareChange] {
        FirmwareHistoryStore.shared.changes(for: device.uniqueIdentifier)
    }

    var body: some View {
        NavigationStack {
            Form {
                signalSection
                networkSection
                compatibilitySection
                meshPathSection
                threadNeighborSection
                deviceSection
                firmwareSection
                if device.batteryPercentage != nil { batterySection }
                if device.isBorderRouter { threadClassificationSection }
                vendorInsightSection
                reliabilitySection
                if #available(iOS 26, *) { aiSummarySection }
                aiAssistantSection
                surveySection
                deviceHistorySection
                notesSection
            }
            .navigationTitle(device.name)
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                noteText = notesStore.note(for: device.uniqueIdentifier.uuidString)
                exportURL = surveyVM.exportCSV(for: device.name)
            }
            .task(id: topologyFingerprint) {
                meshPath = computeMeshPath()
            }
            .task {
                guard #available(iOS 26, *), ProStore.shared.isPro else { return }
                guard !isLoadingDeviceSummary, deviceAISummary == nil else { return }
                isLoadingDeviceSummary = true
                let offlineCount = activityStore.events.filter {
                    $0.deviceID == device.uniqueIdentifier &&
                    ($0.kind == .deviceOffline || $0.kind == .borderRouterOffline) &&
                    $0.timestamp > Date().addingTimeInterval(-30 * 24 * 3600)
                }.count
                deviceAISummary = try? await AINetworkAnalyzer.deviceSummary(
                    device: device,
                    anomaly: meshViewModel.anomalies[device.uniqueIdentifier],
                    stats: statsStore.stats(for: device.uniqueIdentifier),
                    offlineCount: offlineCount
                )
                isLoadingDeviceSummary = false
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showFirmwareHistory) {
                FirmwareHistorySheet(device: device)
            }
            .sheet(item: $troubleshootProblem) { problem in
                TroubleshooterView(device: device, problem: problem)
            }
            .sheet(isPresented: $showAIAssistant) {
                NavigationStack {
                    NetworkAssistantWrapperView(focusDevice: device)
                }
            }
            .sheet(isPresented: $showPaywall) { PaywallView() }
            .sheet(item: $explainContext) { ctx in
                MetricExplainSheet(
                    context: ctx,
                    explanation: metricExplanation,
                    isLoading: isLoadingMetricExplanation
                )
            }
            .task(id: explainContext?.id) {
                guard let ctx = explainContext else { return }
                guard #available(iOS 26, *) else { return }
                isLoadingMetricExplanation = true
                metricExplanation = nil
                metricExplanation = try? await AINetworkAnalyzer.explainMetric(
                    metricName: ctx.metricName,
                    value: ctx.displayValue,
                    context: ctx.aiPromptContext
                )
                isLoadingMetricExplanation = false
            }
        }
    }

    // MARK: - Signal Intelligence

    @ViewBuilder
    private var signalSection: some View {
        Section {
            signalSectionContent
        } header: {
            Text("Signal Intelligence")
        } footer: {
            Text("Signal values are estimated from HomeKit response time — not measured radio RSSI.")
        }
    }

    @ViewBuilder
    private var signalSectionContent: some View {
        Group {
            // Header row: icon + live RSSI + grade
            HStack(spacing: 12) {
                Image(systemName: device.rssi.rssiSystemIcon)
                    .font(.title)
                    .foregroundStyle(currentColor)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text(roleLabel)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    // H4: quality label is the primary display — raw number is latency-estimated
                    Text(currentRSSI.rssiQualityLabel)
                        .font(.title3.bold())
                        .foregroundStyle(currentColor)
                    Text("Response Quality · estimated")
                        .font(.caption2)
                        .foregroundStyle(currentColor.opacity(0.7))
                }

                Spacer()

                if let s = stats {
                    VStack(spacing: 0) {
                        Text(s.healthGrade)
                            .font(.system(.largeTitle, design: .rounded, weight: .bold))
                            .foregroundStyle(s.healthColor)
                        Text("Grade")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text("\(s.stabilityPct)% stable")
                            .font(.caption2)
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

                // Stat cells: Live / Avg / Min / Max  (long-press any cell to explain with AI)
                HStack(spacing: 0) {
                    statCell(value: s.latestRSSI, label: "Live", color: s.latestRSSI.rssiColor) {
                        setExplainContext(metricName: "Live Signal", displayValue: "\(s.latestRSSI) RQ",
                                          aiPromptContext: signalMetricContext(label: "live", value: s.latestRSSI))
                    }
                    Divider().frame(height: 30)
                    statCell(value: s.avgRSSI, label: "Avg", color: s.avgRSSI.rssiColor) {
                        setExplainContext(metricName: "Average Signal", displayValue: "\(s.avgRSSI) RQ",
                                          aiPromptContext: signalMetricContext(label: "average", value: s.avgRSSI))
                    }
                    Divider().frame(height: 30)
                    statCell(value: s.minRSSI, label: "Min", color: s.minRSSI.rssiColor) {
                        setExplainContext(metricName: "Minimum Signal", displayValue: "\(s.minRSSI) RQ",
                                          aiPromptContext: signalMetricContext(label: "minimum", value: s.minRSSI))
                    }
                    Divider().frame(height: 30)
                    statCell(value: s.maxRSSI, label: "Max", color: s.maxRSSI.rssiColor) {
                        setExplainContext(metricName: "Maximum Signal", displayValue: "\(s.maxRSSI) RQ",
                                          aiPromptContext: signalMetricContext(label: "maximum", value: s.maxRSSI))
                    }
                }
                .padding(.vertical, 4)

                // Percentile row (needs ≥ 5 readings for meaningful p95)
                if s.readingCount >= 5 {
                    Divider()
                    HStack(spacing: 0) {
                        percentileCell(value: s.p50, label: "Median", sublabel: "p50")
                        Divider().frame(height: 30)
                        percentileCell(value: s.p95, label: "Worst 10%", sublabel: "p95")
                        Divider().frame(height: 30)
                        jitterCell(jitter: s.jitter, label: s.jitterLabel)
                    }
                    .padding(.vertical, 4)
                }

                // Quality distribution bar
                VStack(alignment: .leading, spacing: 4) {
                    SignalQualityBarView(buckets: s.qualityBuckets)
                        .frame(height: 10)

                    HStack(spacing: 0) {
                        ForEach(s.qualityBuckets.filter { $0.fraction > 0.005 }, id: \.label) { b in
                            HStack(spacing: 2) {
                                Circle().fill(b.color).frame(width: 5, height: 5)
                                Text(String(format: "%d%%", Int(b.fraction * 100)))
                                    .font(.caption2)
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
                    Button("Clear") { statsStore.clear(for: device.uniqueIdentifier) }
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

            // Failure projection (AI-A1) — shown when trajectory is declining/critical
            if let anomaly = meshViewModel.anomalies[device.uniqueIdentifier],
               anomaly.trajectory != .stable,
               let hours = anomaly.projectedHoursToFailure {
                let days = hours / 24
                let timeLabel: String = {
                    if hours < 1 { return "< 1 hour" }
                    if days < 1  { return "\(Int(hours.rounded())) hours" }
                    if days < 2  { return "~1 day" }
                    return "~\(Int(days.rounded())) days"
                }()
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(anomaly.trajectory == .critical ? .red : .orange)
                        .imageScale(.small)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Projected decline to critical: \(timeLabel)")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(anomaly.trajectory == .critical ? .red : .orange)
                        Text("Linear estimate based on current rate of change")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 2)
            }

            // Troubleshooter entry point for offline or weak devices
            let rssi = stats?.latestRSSI ?? device.rssi ?? -65
            if device.isOffline {
                Button {
                    troubleshootProblem = .offline
                } label: {
                    Label("Troubleshoot Offline Device", systemImage: "wrench.and.screwdriver")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .padding(.top, 4)
            } else if rssi.isWeakRSSI {
                Button {
                    troubleshootProblem = .weakSignal
                } label: {
                    Label("Troubleshoot Weak Signal", systemImage: "wrench.and.screwdriver")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .padding(.top, 4)
            }
        }
    }

    private func percentileCell(value: Int, label: String, sublabel: String) -> some View {
        VStack(spacing: 1) {
            Text(value.rssiQualityLabel)
                .font(.caption.weight(.semibold))
                .foregroundStyle(value.rssiColor)
            Text(sublabel)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func jitterCell(jitter: Int, label: String) -> some View {
        VStack(spacing: 1) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(jitter < 10 ? .green : jitter < 20 ? .orange : .red)
            Text("\(jitter) pts spread")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text("Jitter")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func statCell(value: Int, label: String, color: Color, onLongPress: (() -> Void)? = nil) -> some View {
        VStack(spacing: 1) {
            Text("\(value)")
                .font(.caption.weight(.semibold).monospacedDigit())
                .foregroundStyle(color)
            Text("RQ")   // Response Quality — latency-estimated, not radio dBm
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .onLongPressGesture { onLongPress?() }
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
            if let parentRaw = device.parentNodeID {
                let parentName = meshViewModel.devices
                    .first { $0.id.uuidString == parentRaw }?.name ?? parentRaw
                LabeledContent("Parent Node", value: parentName)
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
            .font(.caption.weight(active ? .semibold : .regular))
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(active ? color.opacity(0.15) : Color.secondary.opacity(0.08), in: Capsule())
            .foregroundStyle(active ? color : Color.secondary)
    }

    // MARK: - Compatibility

    @ViewBuilder
    private var compatibilitySection: some View {
        let proto = device.deviceProtocol
        Section {
            HStack(spacing: 12) {
                Image(systemName: proto.icon)
                    .font(.title2)
                    .foregroundStyle(proto.color)
                    .frame(width: 36)
                VStack(alignment: .leading, spacing: 3) {
                    Text(proto.shortLabel)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(proto.color)
                    Text(proto.detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.vertical, 4)
            if proto == .zigbeeBridge {
                Label("Devices behind this hub are not on the Thread mesh", systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        } header: {
            Text("Protocol Compatibility")
        }
    }

    // MARK: - Firmware

    @ViewBuilder
    private var firmwareSection: some View {
        let fwVersion = device.firmwareVersion
        let history = firmwareChanges
        Section {
            LabeledContent("Firmware Version") {
                if let ver = fwVersion {
                    Text(ver)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                } else {
                    Text("Not reported by HomeKit")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            if !history.isEmpty {
                Button {
                    showFirmwareHistory = true
                } label: {
                    HStack {
                        Label("Version History", systemImage: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                        Spacer()
                        Text("^[\(history.count) change](inflect: true)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                .foregroundStyle(.primary)
            }
        } header: {
            Text("Firmware")
        } footer: {
            if fwVersion != nil {
                Text("Firmware version reported by HomeKit. Keep devices updated for the latest Thread and Matter improvements.")
                    .font(.caption)
            }
        }
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
        Section {
            if let batt = device.batteryPercentage {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: batt > 75 ? "battery.100percent" : batt > 50 ? "battery.75percent" : batt > 25 ? "battery.50percent" : batt > 10 ? "battery.25percent" : "battery.0percent")
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

                if device.isSleepyEndDevice, let estimate = batteryDaysEstimate(batt) {
                    HStack {
                        Label("Est. remaining", systemImage: "clock.badge")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(estimate.label)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(estimate.color)
                    }
                }

                if device.isSleepyEndDevice {
                    let eff = radioEfficiency
                    HStack {
                        Label("Radio efficiency", systemImage: "antenna.radiowaves.left.and.right")
                            .font(.caption2).foregroundStyle(.secondary)
                        Spacer()
                        Text(eff.label)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(eff.color)
                    }
                }
            }
        } header: {
            Text("Battery")
        } footer: {
            if device.isSleepyEndDevice {
                Text("Days remaining is an estimate based on typical Thread sensor battery profiles (~90 day total life). Actual life varies by device and usage.")
                    .font(.caption2)
            }
        }
    }

    private var radioEfficiency: (label: LocalizedStringResource, color: Color) {
        let stats = DeviceStatsStore.shared.stats(for: device.uniqueIdentifier)
        let jitter = stats?.jitter ?? 0
        let cutoff = Date().addingTimeInterval(-30 * 24 * 3600)
        let offlineCount = activityStore.events.filter {
            $0.deviceID == device.uniqueIdentifier && $0.kind == .deviceOffline && $0.timestamp > cutoff
        }.count
        if jitter > 20 && offlineCount >= 3 { return ("High Drain", .red) }
        if jitter > 15 || offlineCount >= 2  { return ("Elevated",  .orange) }
        if jitter <= 10 && offlineCount <= 1 { return ("Efficient", .green) }
        return ("Normal", .secondary)
    }

    private func batteryDaysEstimate(_ percent: Int) -> (label: LocalizedStringResource, color: Color)? {
        let totalDays = 90
        let days = Int(Double(percent) / 100.0 * Double(totalDays))
        switch days {
        case 0:       return ("Replace soon", .red)
        case 1...7:   return ("~^[\(days) day](inflect: true)", .red)
        case 8...21:  return ("~\(days) days", .orange)
        default:      return ("~\(days) days", .secondary)
        }
    }

    // MARK: - Thread Classification Override

    @ViewBuilder
    private var threadClassificationSection: some View {
        let isExcluded = overrideStore.isNonThread(device.id)
        Section {
            Toggle(isOn: Binding(
                get: { !isExcluded },
                set: { overrideStore.setNonThread(device.id, !$0) }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Include in Thread mesh")
                    Text("Disable if this bridge uses Zigbee, Z-Wave, or another non-Thread protocol. HomeKit classifies all bridges as border routers regardless of radio type.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .tint(.blue)
        } header: {
            Text("Thread Classification")
        } footer: {
            if isExcluded {
                Text("This device is hidden from the mesh map and topology. It still appears in lists and the dashboard.")
                    .foregroundStyle(.orange)
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

            if let url = exportURL {
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
                .font(.caption2)
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

    // MARK: - AI Assistant

    @available(iOS 26, *)
    @ViewBuilder
    private var aiSummarySection: some View {
        if isLoadingDeviceSummary || deviceAISummary != nil {
            Section {
                if isLoadingDeviceSummary {
                    HStack(spacing: 10) {
                        ProgressView().controlSize(.small)
                        Text("Generating AI analysis…").font(.caption).foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 6)
                } else if let summary = deviceAISummary {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Image(systemName: "apple.intelligence").font(.caption).foregroundStyle(.purple)
                            Text("AI Analysis").font(.caption.weight(.semibold)).foregroundStyle(.purple)
                        }
                        Text(summary)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.vertical, 4)
                }
            } header: {
                Label("AI Device Summary", systemImage: "sparkles")
            }
        }
    }

    private var aiAssistantSection: some View {
        Section {
            Button {
                if ProStore.shared.isPro { showAIAssistant = true }
                else { showPaywall = true }
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        Circle().fill(Color.purple.opacity(0.12)).frame(width: 34, height: 34)
                        Image(systemName: "bubble.left.and.text.bubble.right.fill")
                            .foregroundStyle(.purple).font(.caption)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Ask AI about this device")
                            .font(.subheadline.weight(.medium))
                        Text("Get personalised advice and diagnostics")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.tertiaryLabel)
                }
                .padding(.vertical, 2)
            }
            .buttonStyle(.plain)
        } header: {
            Text("AI Insights")
        }
    }

    // MARK: - Vendor Insight

    @ViewBuilder
    private var vendorInsightSection: some View {
        if let insight = vendorInsight {
            Section {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "lightbulb.fill")
                        .foregroundStyle(.yellow)
                        .imageScale(.small)
                        .padding(.top, 1)
                    Text(insight)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 2)
            } header: {
                Text("Vendor Notes")
            }
        }
    }

    private var vendorInsight: String? {
        let mfr = device.manufacturer.lowercased()
        if mfr.contains("eve") {
            return "Eve devices are native Thread. Mains-powered Eve accessories (Eve Energy, Eve Outdoor Plug) act as Thread routers — place them strategically to extend your mesh reach."
        }
        if mfr.contains("nanoleaf") {
            return "Nanoleaf Thread devices act as mesh routers when mains-powered. Large glass or metal panels can absorb 2.4 GHz signal — position them as relays, not dead ends."
        }
        if mfr.contains("apple") {
            return "HomePod mini and Apple TV 4K are Thread border routers. Keep them updated via Settings → General → Software Update for the latest Thread firmware improvements."
        }
        if mfr.contains("ikea") {
            return "IKEA DIRIGERA hub uses Zigbee, not Thread. Look for the Thread logo on IKEA packaging — compatible models include Trådfri and Symfonisk (2nd gen)."
        }
        if mfr.contains("philips") || mfr.contains("hue") || mfr.contains("signify") {
            return "Philips Hue Bridge uses Zigbee. Newer Hue devices support Matter over Thread — use the Hue app to migrate eligible bulbs to your Thread fabric."
        }
        if mfr.contains("aqara") {
            return "Aqara M2/M3 hubs bridge multiple protocols. Thread-capable Aqara devices may appear as proxied through the hub rather than directly on the mesh."
        }
        if mfr.contains("bosch") {
            return "Bosch Smart Home devices typically operate as sleepy end devices — waking only to transmit. Higher response latency is expected and normal for battery-powered Bosch sensors."
        }
        if mfr.contains("samsung") || mfr.contains("smartthings") {
            return "Samsung SmartThings Station supports Thread and Matter. It can act as a border router for your mesh alongside HomePod and Apple TV devices."
        }
        return nil
    }

    // MARK: - Reliability

    private var reliabilitySection: some View {
        let cutoff = Date().addingTimeInterval(-30 * 24 * 3600)
        let offlineEvents = activityStore.events.filter {
            $0.deviceID == device.uniqueIdentifier &&
            ($0.kind == .deviceOffline || $0.kind == .borderRouterOffline) &&
            $0.timestamp > cutoff
        }
        let count = offlineEvents.count
        let (label, color): (String, Color) = switch count {
        case 0:        ("Excellent", .green)
        case 1:        ("Very Good", .mint)
        case 2:        ("Good",      .yellow)
        case 3...4:    ("Fair",      .orange)
        default:       ("Needs Attention", .red)
        }

        let lastOfflineDate = offlineEvents.first?.timestamp
        let streakDays: Int? = lastOfflineDate.map { Int(Date().timeIntervalSince($0) / 86400) }

        return Section {
            LabeledContent("30-day Reliability") {
                HStack(spacing: 6) {
                    Circle().fill(color).frame(width: 8, height: 8)
                    Text(label).foregroundStyle(color).fontWeight(.medium)
                }
            }
            LabeledContent("Offline Events (30 days)") {
                Text(count == 0 ? "None" : "\(count)")
                    .foregroundStyle(count == 0 ? .green : count < 3 ? .primary : .red)
            }
            if let days = streakDays {
                LabeledContent("Online Streak") {
                    Text(days == 0 ? "< 1 day" : "^[\(days) day](inflect: true)")
                        .foregroundStyle(.secondary)
                }
            } else {
                LabeledContent("Online Streak") {
                    Text("No outages recorded").foregroundStyle(.green)
                }
            }
        } header: {
            Text("Reliability")
        } footer: {
            Text("Based on activity events recorded by ThreadMapper in the last 30 days.")
        }
    }

    // MARK: - Device History

    private var deviceEvents: [ActivityEvent] {
        activityStore.events.filter { $0.deviceID == device.id }
    }

    @ViewBuilder
    private var deviceHistorySection: some View {
        let events = deviceEvents
        if !events.isEmpty {
            Section("Device History") {
                let offlineEvents = events.filter { $0.kind == .deviceOffline }
                let joinEvents = events.filter { $0.kind == .topologyJoined }

                if let firstSeen = joinEvents.last {
                    LabeledContent("First Seen") {
                        Text(firstSeen.timestamp, format: .dateTime.month().day().year())
                            .font(.caption.monospacedDigit())
                    }
                }

                if !offlineEvents.isEmpty {
                    LabeledContent("Offline Events (7d)") {
                        Text("\(offlineEvents.count)")
                            .font(.caption.weight(.semibold).monospacedDigit())
                            .foregroundStyle(offlineEvents.count >= 5 ? .red : offlineEvents.count >= 2 ? .orange : .secondary)
                    }
                }

                if let latest = events.first {
                    HStack(spacing: 8) {
                        Image(systemName: latest.kind.icon)
                            .foregroundStyle(latest.kind.color)
                            .imageScale(.small)
                        Text(latest.kind.label)
                            .font(.caption)
                        Spacer()
                        Text(latest.timestamp, style: .relative)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        Text("ago")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private var networkAvgRSSI: Int? {
        let values = meshViewModel.devices.compactMap { $0.rssi }.filter { $0 != 0 }
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / values.count
    }

    func setExplainContext(metricName: String, displayValue: String, aiPromptContext: String) {
        guard ProStore.shared.isPro else { showPaywall = true; return }
        if #available(iOS 26, *) {
            metricExplanation = nil
            explainContext = MetricExplanationContext(
                metricName: metricName,
                displayValue: displayValue,
                aiPromptContext: aiPromptContext
            )
        }
    }

    private func signalMetricContext(label: String, value: Int) -> String {
        var parts = ["Device: \(device.name)\(device.room.map { " in \($0)" } ?? "")."]
        parts.append("Metric: \(label) signal = \(value) Response Quality (RQ) units. RQ is estimated from HomeKit response latency — higher values mean better connectivity.")
        if let avg = networkAvgRSSI {
            parts.append("Network average across all devices: \(avg) RQ.")
        }
        parts.append("Quality label for this value: '\(value.rssiQualityLabel)'.")
        if let a = meshViewModel.anomalies[device.uniqueIdentifier], a.trajectory != .stable {
            parts.append("Current signal trend: \(a.trajectory.label). Signal has dropped \(String(format: "%.0f", a.dropDelta)) RQ units from baseline.")
        }
        return parts.joined(separator: " ")
    }

    private var currentRSSI: Int { stats?.latestRSSI ?? device.rssi ?? -65 }
    private var currentColor: Color { currentRSSI.rssiColor }

    private var roleLabel: String {
        if device.isBorderRouter { return "Border Router" }
        if device.isRouter { return "Router" }
        if device.isSleepyEndDevice { return "Sleepy End Device" }
        return "End Device"
    }
}

// MARK: - Metric Explain Sheet

private struct MetricExplainSheet: View {
    let context: DeviceDetailView.MetricExplanationContext
    let explanation: String?
    let isLoading: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(context.metricName)
                        .font(.title3.weight(.semibold))
                    Text(context.displayValue)
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                Divider()

                if isLoading {
                    HStack(spacing: 10) {
                        ProgressView().controlSize(.small)
                        Text("Asking AI…")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } else if let text = explanation {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .font(.caption)
                            .foregroundStyle(.purple)
                        Text("AI Explanation")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.purple)
                    }
                    Text(text)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("AI explanation unavailable.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .navigationTitle("Explain This")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.fraction(0.4)])
    }
}
