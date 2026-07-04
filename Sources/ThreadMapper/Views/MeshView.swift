import SwiftUI
import Observation

struct MeshView: View {
    @Environment(MeshViewModel.self) private var viewModel

    // Explicit bindings since @Environment properties can't produce $bindings directly
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
        NavigationStack {
            VStack(spacing: 0) {
                filterBar
                MeshGraphView(
                    nodes: viewModel.nodes,
                    links: viewModel.links,
                    devices: viewModel.devices,
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
                // Use .sheet instead of .popover — popover on iPhone becomes a sheet anyway
                // but causes presentation issues inside a Canvas-based view.
                .sheet(item: selectedDeviceBinding) { device in
                    DeviceDetailView(device: device)
                        .presentationDetents([.large])
                }
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task { await viewModel.startScan() }
                    } label: {
                        if viewModel.isScanning {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Label("Scan", systemImage: "antenna.radiowaves.left.and.right")
                        }
                    }
                    .disabled(viewModel.isScanning)
                }
            }
            .navigationTitle("Mesh")
            .overlay(alignment: .top) {
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

    @ViewBuilder
    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
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
                            .font(.caption)
                    }
                }

                Spacer(minLength: 0)

                Text("\(viewModel.visibleDeviceCount) device\(viewModel.visibleDeviceCount == 1 ? "" : "s")")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.trailing, 4)
            }
            .padding(.horizontal, 12)
        }
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }

    @ViewBuilder
    private func filterChip(label: String, icon: String, active: Bool) -> some View {
        Label(label, systemImage: icon)
            .font(.caption.weight(.medium))
            .lineLimit(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(active ? Color.accentColor : Color.secondary.opacity(0.15),
                        in: Capsule())
            .foregroundStyle(active ? .white : .primary)
    }

    @ViewBuilder
    private func errorBanner(message: String) -> some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.octagon.fill")
                    .foregroundStyle(.white)
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.leading)
            }
            Button("Retry") {
                Task { await viewModel.startScan() }
            }
            .font(.caption2)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.white.opacity(0.2), in: Capsule())
            .foregroundStyle(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.red, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .padding(.top, 8)
        .padding(.horizontal, 16)
    }
}
