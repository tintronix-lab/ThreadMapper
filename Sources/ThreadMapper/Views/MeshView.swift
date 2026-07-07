import SwiftUI
import Observation

struct MeshView: View {
    @Environment(MeshViewModel.self) private var viewModel

    private var roomBinding: Binding<String?> {
        Binding(get: { viewModel.selectedRoom }, set: { viewModel.selectedRoom = $0 })
    }
    private var channelBinding: Binding<Int?> {
        Binding(get: { viewModel.selectedChannel }, set: { viewModel.selectedChannel = $0 })
    }
    private var selectedDeviceBinding: Binding<ThreadDevice?> {
        Binding(get: { viewModel.selectedDevice }, set: { viewModel.selectedDevice = $0 })
    }

    var body: some View {
        MeshGraphView(
            nodes: viewModel.nodes,
            links: viewModel.links,
            devices: viewModel.devices,
            isLive: viewModel.topologySource == .liveOTBR,
            onSelectNode: { node in
                if let deviceID = node.deviceID,
                   let device = viewModel.devices.first(where: { $0.id == deviceID }) {
                    viewModel.selectedDevice = device
                    viewModel.selectedNode = node
                }
            },
            onSelectDevice: { device in
                viewModel.selectedDevice = device
                if device == nil { viewModel.selectedNode = nil }
            }
        )
        .sheet(item: selectedDeviceBinding) { device in
            DeviceDetailView(device: device)
                .presentationDetents([.large])
        }
        // Filter bar + error banner float above the graph; safeAreaInset
        // shrinks the graph's available size correctly so layout isn't obscured.
        .safeAreaInset(edge: .top, spacing: 0) {
            VStack(spacing: 0) {
                filterBar
                if !viewModel.threadNetworks.isEmpty {
                    threadNetworkBar
                }
                if let error = viewModel.scanError {
                    errorBanner(message: error)
                }
            }
        }
        .onAppear {
            if !viewModel.isScanning {
                Task { await viewModel.startScan() }
            }
        }
    }

    // MARK: - Filter bar

    @ViewBuilder
    private var filterBar: some View {
        HStack(spacing: 6) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    Menu {
                        Picker("Room", selection: roomBinding) {
                            Text("All Rooms").tag(String?.none)
                            ForEach(viewModel.rooms, id: \.self) { room in
                                Text(room).tag(String?(room))
                            }
                        }
                        .pickerStyle(.inline)
                    } label: {
                        filterChip(
                            label: viewModel.selectedRoom ?? "All Rooms",
                            icon: "house",
                            active: viewModel.selectedRoom != nil
                        )
                    }

                    Menu {
                        Picker("Channel", selection: channelBinding) {
                            Text("All Channels").tag(Int?.none)
                            ForEach(viewModel.channels, id: \.self) { ch in
                                Text("CH \(ch)").tag(Int?(ch))
                            }
                        }
                        .pickerStyle(.inline)
                    } label: {
                        filterChip(
                            label: viewModel.selectedChannel.map { "CH \($0)" } ?? "All Channels",
                            icon: "wifi",
                            active: viewModel.selectedChannel != nil
                        )
                    }

                    if viewModel.selectedRoom != nil || viewModel.selectedChannel != nil {
                        Button {
                            withAnimation {
                                viewModel.selectedRoom = nil
                                viewModel.selectedChannel = nil
                            }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                                .font(.caption2)
                        }
                    }
                }
            }

            Spacer(minLength: 4)

            Text("\(viewModel.visibleDeviceCount)")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)

            // Scan button inline in filter bar
            Button {
                Task { await viewModel.startScan() }
            } label: {
                if viewModel.isScanning {
                    ProgressView().controlSize(.mini)
                } else {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.caption2)
                }
            }
            .disabled(viewModel.isScanning)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial)
    }

    // MARK: - Real Thread network facts (Feature #2, Phase 1)

    @ViewBuilder
    private var threadNetworkBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(viewModel.threadNetworks) { net in
                    HStack(spacing: 5) {
                        Image(systemName: "point.3.filled.connected.trianglepath.dotted")
                            .font(.system(size: 9))
                            .foregroundStyle(.green)
                        Text(net.networkName)
                            .font(.caption2.weight(.semibold))
                        if let ch = net.channel {
                            Text("· CH \(ch)")
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        if let pan = net.panID {
                            Text("· PAN \(pan)")
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.green.opacity(0.12), in: Capsule())
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
        }
        .background(.ultraThinMaterial)
    }

    // MARK: - Filter chip

    @ViewBuilder
    private func filterChip(label: String, icon: String, active: Bool) -> some View {
        Label(label, systemImage: icon)
            .font(.caption2.weight(.medium))
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(active ? Color.accentColor : Color.secondary.opacity(0.15), in: Capsule())
            .foregroundStyle(active ? .white : .primary)
    }

    // MARK: - Error banner

    @ViewBuilder
    private func errorBanner(message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.octagon.fill")
                .foregroundStyle(.white)
                .imageScale(.small)
            Text(message)
                .font(.caption2)
                .foregroundStyle(.white)
                .lineLimit(2)
            Spacer(minLength: 0)
            Button("Retry") {
                Task { await viewModel.startScan() }
            }
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.white.opacity(0.2), in: Capsule())
            .foregroundStyle(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.red)
    }
}
