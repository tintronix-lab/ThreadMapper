import SwiftUI
import Observation

struct DashboardView: View {
    @Environment(MeshViewModel.self) private var viewModel
    @State private var selectedRoom: String? = nil
    @State private var sortOrder: SortOrder = .name

    init() {}

    private var filteredDevices: [ThreadDevice] {
        let base = selectedRoom == nil ? viewModel.devices : viewModel.devices.filter { $0.room == selectedRoom }
        switch sortOrder {
        case .name: return base.sorted { $0.name < $1.name }
        case .type: return base.sorted { $0.deviceType < $1.deviceType }
        case .signal: return base.sorted { ($0.rssi ?? -999) > ($1.rssi ?? -999) }
        }
    }

    private var rooms: [String] {
        Array(Set(viewModel.devices.compactMap(\.room))).sorted()
    }

    var body: some View {
        NavigationStack {
            List {
                if !viewModel.warnings().isEmpty {
                    Section("Alerts") {
                        ForEach(viewModel.warnings(), id: \.self) { msg in
                            Text(msg).foregroundStyle(.orange)
                        }
                    }
                }

                Section {
                    ForEach(filteredDevices) { device in
                        DeviceListRow(device: device)
                            .onTapGesture { viewModel.selectedDevice = device }
                    }
                }
                Section {
                    EmptyView()
                } footer: {
                    Text("\(filteredDevices.count) device(s) shown")
                }
            }
            .navigationTitle("Thread Mesh")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task { await viewModel.startScan() }
                    } label: {
                        if viewModel.isScanning { ProgressView() } else { Label("Scan", systemImage: "antenna.radiowaves.left.and.right") }
                    }
                    .disabled(viewModel.isScanning)
                }
            }
            .overlay {
                if let error = viewModel.scanError {
                    VStack {
                        Text(error).foregroundStyle(.red).padding()
                        Button("Dismiss") { viewModel.scanError = nil }
                    }
                }
            }
            .safeAreaInset(edge: .top) {
                VStack(spacing: 0) {
                    RoomFilterView(selectedRoom: $selectedRoom, rooms: rooms)
                    Picker("Sort", selection: $sortOrder) {
                        Text("Name").tag(SortOrder.name)
                        Text("Type").tag(SortOrder.type)
                        Text("Signal").tag(SortOrder.signal)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                    Divider()
                }
                .background(.regularMaterial)
            }
        }
    }

    enum SortOrder: String, CaseIterable, Identifiable {
        case name, type, signal
        var id: String { rawValue }
    }
}
