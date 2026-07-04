import SwiftUI
import Observation

struct DashboardView: View {
    @Environment(MeshViewModel.self) private var viewModel
    @Environment(DeviceStatsStore.self) private var statsStore
    @State private var selectedDevice: ThreadDevice?
    @State private var selectedRoom: String? = nil

    private var health: NetworkHealthScore {
        NetworkHealthScore.compute(devices: viewModel.devices)
    }

    private var roomGroups: [(room: String, devices: [ThreadDevice])] {
        Dictionary(grouping: viewModel.devices) { $0.room ?? "Unknown" }
            .map { (room: $0.key, devices: $0.value) }
            .sorted { $0.room < $1.room }
    }

    private var filteredDevices: [ThreadDevice] {
        guard let room = selectedRoom else { return viewModel.devices }
        return viewModel.devices.filter { $0.room == room }
    }

    var body: some View {
        NavigationStack {
            List {
                healthSection
                if !health.issues.filter(\.isCritical).isEmpty || !health.issues.isEmpty {
                    issuesSection
                }
                if !health.tips.isEmpty {
                    tipsSection
                }
                trendSection
                if !roomGroups.isEmpty {
                    roomCoverageSection
                }
                deviceSection
            }
            .navigationTitle("Dashboard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task { await viewModel.startScan() }
                    } label: {
                        if viewModel.isScanning {
                            ProgressView().controlSize(.small)
                        } else {
                            Label("Rescan", systemImage: "arrow.clockwise")
                                .font(.caption.weight(.medium))
                        }
                    }
                    .disabled(viewModel.isScanning)
                }
            }
            .sheet(item: $selectedDevice) { device in
                DeviceDetailView(device: device)
            }
            .onAppear {
                if !viewModel.isScanning {
                    Task { await viewModel.startScan() }
                }
            }
        }
    }

    // MARK: - Health Score Hero

    @ViewBuilder
    private var healthSection: some View {
        Section {
            HStack(alignment: .center, spacing: 16) {
                // Grade ring
                ZStack {
                    Circle()
                        .stroke(health.color.opacity(0.2), lineWidth: 4)
                        .frame(width: 76, height: 76)
                    Circle()
                        .trim(from: 0, to: CGFloat(health.score) / 100)
                        .stroke(health.color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .frame(width: 76, height: 76)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeOut(duration: 0.6), value: health.score)
                    VStack(spacing: 0) {
                        Text(health.grade)
                            .font(.system(size: 30, weight: .black, design: .rounded))
                            .foregroundStyle(health.color)
                        Text("\(health.score)")
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundStyle(health.color.opacity(0.7))
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(health.summary)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(2)

                    HStack(spacing: 8) {
                        statChip("\(viewModel.devices.count)", "Devices", "cpu")
                        statChip("\(viewModel.devices.filter(\.isBorderRouter).count)", "Routers", "antenna.radiowaves.left.and.right")
                        let weak = viewModel.devices.filter { ($0.rssi ?? -65) < -80 }.count
                        if weak > 0 {
                            statChip("\(weak)", "Weak", "wifi.exclamationmark", color: .orange)
                        }
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 4)
        } header: {
            Text("Network Health")
        }
    }

    @ViewBuilder
    private func statChip(_ value: String, _ label: String, _ icon: String, color: Color = .secondary) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon).imageScale(.small)
            Text(value).fontWeight(.semibold)
            Text(label)
        }
        .font(.caption2)
        .foregroundStyle(color)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(.quaternary, in: Capsule())
    }

    // MARK: - Issues

    @ViewBuilder
    private var issuesSection: some View {
        Section("Issues") {
            ForEach(health.issues) { issue in
                HStack(spacing: 10) {
                    Image(systemName: issue.icon)
                        .foregroundStyle(issue.isCritical ? .red : .orange)
                        .imageScale(.small)
                        .frame(width: 18)
                    Text(issue.message)
                        .font(.subheadline)
                    Spacer()
                    if issue.isCritical {
                        Text("Critical")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.red)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.red.opacity(0.1), in: Capsule())
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    // MARK: - Tips

    @ViewBuilder
    private var tipsSection: some View {
        Section("Recommendations") {
            ForEach(Array(health.tips.enumerated()), id: \.offset) { _, tip in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "lightbulb.fill")
                        .foregroundStyle(.yellow)
                        .imageScale(.small)
                        .frame(width: 18)
                    Text(tip)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Trend Sparkline

    @ViewBuilder
    private var trendSection: some View {
        let buckets = statsStore.networkTrendBuckets()
        if buckets.count >= 3 {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Network Signal — Last 30 min")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Spacer()
                        if let last = buckets.last {
                            Text("\(last.avgRSSI) dBm avg")
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(last.avgRSSI > -65 ? .green : last.avgRSSI > -80 ? .orange : .red)
                        }
                    }
                    let readings = buckets.map {
                        DeviceStatsStore.Reading(timestamp: $0.timestamp, rssi: $0.avgRSSI)
                    }
                    SignalSparklineView(readings: readings)
                        .frame(height: 56)
                }
                .padding(.vertical, 4)
            }
        }
    }

    // MARK: - Room Coverage

    @ViewBuilder
    private var roomCoverageSection: some View {
        Section {
            ForEach(roomGroups, id: \.room) { group in
                roomRow(group.room, group.devices)
            }
        } header: {
            HStack {
                Text("Room Coverage")
                Spacer()
                if selectedRoom != nil {
                    Button("Show All") { selectedRoom = nil }
                        .font(.caption)
                }
            }
        }
    }

    @ViewBuilder
    private func roomRow(_ room: String, _ devices: [ThreadDevice]) -> some View {
        let offline = devices.filter { $0.rssi == -100 }.count
        let weak = devices.filter { let r = $0.rssi ?? -65; return r < -80 && r > -100 }.count
        let grades = devices.compactMap { statsStore.stats(for: $0.name)?.healthGrade }
        let worstGrade = ["F", "D", "C", "B", "A"].first { grades.contains($0) }

        Button {
            selectedRoom = selectedRoom == room ? nil : room
        } label: {
            HStack(spacing: 10) {
                Image(systemName: roomIcon(room))
                    .foregroundStyle(selectedRoom == room ? Color.accentColor : Color.secondary)
                    .imageScale(.small)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 2) {
                    Text(room)
                        .font(.subheadline.weight(selectedRoom == room ? .semibold : .regular))
                        .foregroundStyle(.primary)
                    HStack(spacing: 6) {
                        Text("\(devices.count) device\(devices.count == 1 ? "" : "s")")
                            .font(.caption2).foregroundStyle(.secondary)
                        if weak > 0 {
                            Text("· \(weak) weak").font(.caption2).foregroundStyle(.orange)
                        }
                        if offline > 0 {
                            Text("· \(offline) offline").font(.caption2).foregroundStyle(.red)
                        }
                    }
                }

                Spacer()

                if let g = worstGrade {
                    Text(g)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(gradeColor(g))
                }

                Image(systemName: selectedRoom == room ? "chevron.down" : "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .buttonStyle(.plain)
        .padding(.vertical, 2)
    }

    // MARK: - Device List

    @ViewBuilder
    private var deviceSection: some View {
        Section {
            if filteredDevices.isEmpty {
                if viewModel.isScanning {
                    HStack {
                        Spacer()
                        VStack(spacing: 8) {
                            ProgressView()
                            Text("Contacting HomeKit…")
                                .foregroundStyle(.secondary)
                                .font(.subheadline)
                        }
                        .padding()
                        Spacer()
                    }
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("No Thread devices found", systemImage: "network.slash")
                            .font(.subheadline).foregroundStyle(.secondary)
                        Text("Open the Home app and add your Thread border router and accessories, then tap Rescan.")
                            .font(.caption).foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 6)
                }
            } else {
                ForEach(filteredDevices) { device in
                    DeviceListRow(device: device)
                        .onTapGesture { selectedDevice = device }
                }
            }
        } header: {
            HStack {
                Text(selectedRoom ?? "All Devices")
                Spacer()
                if selectedRoom != nil {
                    Button("Clear Filter") { selectedRoom = nil }
                        .font(.caption)
                }
            }
        }
    }

    // MARK: - Helpers

    private func roomIcon(_ room: String) -> String {
        let l = room.lowercased()
        if l.contains("kitchen")  { return "oven.fill" }
        if l.contains("bedroom")  { return "bed.double.fill" }
        if l.contains("living")   { return "sofa.fill" }
        if l.contains("bath")     { return "shower.fill" }
        if l.contains("garage")   { return "car.fill" }
        if l.contains("office")   { return "desktopcomputer" }
        if l.contains("garden") || l.contains("outdoor") { return "leaf.fill" }
        if l.contains("hall")     { return "door.left.hand.open" }
        return "house.fill"
    }

    private func gradeColor(_ grade: String) -> Color {
        switch grade {
        case "A": return .green
        case "B": return .mint
        case "C": return .yellow
        case "D": return .orange
        default:  return .red
        }
    }
}
