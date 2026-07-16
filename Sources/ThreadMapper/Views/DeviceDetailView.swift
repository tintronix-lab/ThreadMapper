import SwiftUI

struct DeviceDetailView: View {
    let device: ThreadDevice
    @Environment(\.dismiss) private var dismiss
    @Environment(MeshViewModel.self) private var meshViewModel
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
            } else if rssi < -80 {
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

    private func statCell(value: Int, label: String, color: Color) -> some View {
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
                        Text("\(history.count) change\(history.count == 1 ? "" : "s")")
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
        Section("Battery") {
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
            }
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

    // MARK: - Thread Neighbor Table (real OTBR data when available)

    @ViewBuilder
    private var threadNeighborSection: some View {
        if let diag = meshViewModel.latestDiagnostics[device.id], !diag.neighbors.isEmpty {
            Section {
                ForEach(diag.neighbors.indices, id: \.self) { i in
                    let neighbor = diag.neighbors[i]
                    HStack(spacing: 12) {
                        Image(systemName: neighbor.isChild ? "arrow.down.circle" : "arrow.up.arrow.down.circle")
                            .foregroundStyle(neighbor.isChild ? .blue : .purple)
                            .imageScale(.small)
                            .frame(width: 22)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(String(format: "0x%04X", neighbor.rloc16))
                                .font(.caption.monospaced())
                            Text(neighbor.isChild ? "Child device" : "Router neighbor")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        // Link quality indicator
                        VStack(alignment: .trailing, spacing: 2) {
                            if let rssi = neighbor.averageRSSI {
                                Text("\(rssi) dBm")
                                    .font(.caption2.monospacedDigit())
                                    .foregroundStyle(rssi.rssiColor)
                            }
                            if let margin = neighbor.linkMarginDB {
                                Text("\(margin) dB margin")
                                    .font(.caption2.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
            } header: {
                HStack {
                    Text("Live Thread Neighbors")
                    Spacer()
                    Label("OTBR", systemImage: "antenna.radiowaves.left.and.right")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.green)
                }
            } footer: {
                Text("Real neighbor data from your OpenThread Border Router. RLOC16 is each node's Thread routing address. Children route through this device; router neighbors are peers on the mesh backbone.")
                    .font(.caption)
            }
        }
    }

    // MARK: - Mesh Path

    private struct HopEntry {
        let name: String
        let kind: MeshNodeKind
        let isCurrentDevice: Bool
    }

    private var meshPath: [HopEntry] {
        let (nodes, _) = MeshTopologyBuilder.buildGraph(from: meshViewModel.devices)
        let nodeByID = Dictionary(uniqueKeysWithValues: nodes.map { ($0.id, $0) })

        var path: [MeshNode] = []
        var current: UUID? = device.id
        var visited = Set<UUID>()

        while let id = current, !visited.contains(id), path.count < 12 {
            visited.insert(id)
            if let node = nodeByID[id] {
                path.append(node)
                current = node.parentID
            } else {
                break
            }
        }
        // Include the gateway if the last node's parentID resolves
        if let lastParentID = path.last?.parentID, let gateway = nodeByID[lastParentID] {
            path.append(gateway)
        }

        return path.reversed().map {
            HopEntry(name: $0.name, kind: $0.kind, isCurrentDevice: $0.id == device.id)
        }
    }

    @ViewBuilder
    private var meshPathSection: some View {
        let path = meshPath
        if path.count >= 2 {
            Section {
                // Hop count row
                let hopCount = path.count - 1  // gateway excluded from "hops"
                HStack(spacing: 10) {
                    Image(systemName: hopCount <= 2 ? "checkmark.circle.fill" : hopCount == 3 ? "exclamationmark.circle" : "exclamationmark.triangle.fill")
                        .foregroundStyle(hopCount <= 2 ? .green : hopCount == 3 ? .orange : .red)
                    Text("\(hopCount) hop\(hopCount == 1 ? "" : "s") from border router")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                }
                .padding(.vertical, 2)

                // Visual hop chain
                ForEach(path.indices, id: \.self) { i in
                    let hop = path[i]
                    VStack(alignment: .leading, spacing: 0) {
                        if i > 0 {
                            HStack {
                                Spacer().frame(width: 10)
                                Image(systemName: "chevron.up")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary.opacity(0.5))
                                Spacer()
                            }
                        }
                        HStack(spacing: 10) {
                            Image(systemName: nodeKindIcon(hop.kind))
                                .foregroundStyle(hop.isCurrentDevice ? Color.accentColor : hop.kind == .gateway ? .blue : .secondary)
                                .frame(width: 22)
                            Text(hop.name)
                                .font(hop.isCurrentDevice ? .subheadline.weight(.semibold) : .subheadline)
                                .foregroundStyle(hop.isCurrentDevice ? .primary : .secondary)
                            Spacer()
                            Text(hop.kind.rawValue)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            } header: {
                Text("Mesh Path to Internet")
            } footer: {
                Text("Inferred routing path from this device to your border router. Fewer hops means lower latency and better reliability.")
                    .font(.caption)
            }
        }
    }

    private func nodeKindIcon(_ kind: MeshNodeKind) -> String {
        switch kind {
        case .gateway:      return "globe"
        case .borderRouter: return "antenna.radiowaves.left.and.right"
        case .router:       return "point.3.connected.trianglepath.dotted"
        case .endDevice:    return "circle.dotted"
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

    private var currentRSSI: Int { stats?.latestRSSI ?? device.rssi ?? -65 }
    private var currentColor: Color { currentRSSI.rssiColor }

    private var roleLabel: String {
        if device.isBorderRouter { return "Border Router" }
        if device.isRouter { return "Router" }
        if device.isSleepyEndDevice { return "Sleepy End Device" }
        return "End Device"
    }
}
