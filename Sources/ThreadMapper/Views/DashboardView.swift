import SwiftUI
import Observation

struct DashboardView: View {
    @Environment(MeshViewModel.self) private var viewModel
    @State private var selectedDevice: ThreadDevice?
    @State private var selectedRoom: String? = nil

    var filteredDevices: [ThreadDevice] {
        let all = viewModel.devices
        guard let room = selectedRoom else { return all }
        return all.filter { $0.room == room }
    }

    var body: some View {
        NavigationStack {
            List {
                summarySection
                filterSection
                weakSpotsSection
                deviceSection
            }
            .navigationTitle("Dashboard")
            .navigationBarTitleDisplayMode(.inline)
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

    @ViewBuilder
    private var summarySection: some View {
        Section {
            let devices = viewModel.devices
            let routers = devices.filter { $0.isRouter || $0.isBorderRouter }
            let weak = devices.filter { ($0.rssi ?? -120) < -80 }
            HStack {
                statCell(value: "\(devices.count)", label: "Devices")
                Spacer()
                statCell(value: "\(routers.count)", label: "Routers")
                Spacer()
                statCell(
                    value: "\(weak.count)",
                    label: "Weak",
                    valueColor: weak.isEmpty ? .green : .red
                )
            }
            .padding(.vertical, 2)
        }
    }

    @ViewBuilder
    private func statCell(value: String, label: String, valueColor: Color = .primary) -> some View {
        VStack(alignment: .center, spacing: 1) {
            Text(value)
                .font(.title3.bold())
                .foregroundStyle(valueColor)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var filterSection: some View {
        let rooms = Array(Set(viewModel.devices.compactMap { $0.room })).sorted()
        if !rooms.isEmpty {
            Section {
                RoomFilterView(selectedRoom: $selectedRoom, rooms: rooms)
            }
        }
    }

    @ViewBuilder
    private var weakSpotsSection: some View {
        let weak = filteredDevices.filter { ($0.rssi ?? -120) < -80 }
        if !weak.isEmpty {
            Section("Weak Spots") {
                ForEach(weak) { device in
                    HStack(alignment: .center, spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                            .imageScale(.small)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(device.name)
                                .font(.subheadline.weight(.medium))
                                .lineLimit(1)
                            Text(device.room ?? "Unknown Room")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if let rssi = device.rssi {
                            Text("\(rssi) dBm")
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(.orange)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    @ViewBuilder
    private var deviceSection: some View {
        Section("Devices") {
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
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text("Open the Home app and add your Thread border router and accessories, then tap Scan.")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 6)
                }
            } else {
                ForEach(filteredDevices) { device in
                    DeviceListRow(device: device)
                        .onTapGesture { selectedDevice = device }
                }
            }
        }
    }
}
