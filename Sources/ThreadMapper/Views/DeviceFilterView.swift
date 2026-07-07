import SwiftUI

/// Navigation value pushed onto DashboardView's NavigationPath to drill into a filtered device list.
///
/// Carries a *category*, not a captured `[ThreadDevice]` snapshot, so the pushed
/// screen re-resolves against the live view model on every render instead of
/// freezing the membership at push time (fixes D3).
struct DeviceFilterSpec: Hashable {
    enum Category: Hashable {
        case all
        case routers
        case offline
        case weak
        /// Explicit device set (e.g. an issue's affected devices), re-resolved
        /// live by `uniqueIdentifier` so devices that leave the network drop out.
        case ids([UUID])
    }

    let title: String
    let category: Category

    func resolve(from devices: [ThreadDevice]) -> [ThreadDevice] {
        switch category {
        case .all:     return devices
        case .routers: return devices.filter(\.isRoutingCapable)
        case .offline: return devices.filter(\.isOffline)
        case .weak:    return devices.filter(\.isWeak)
        case .ids(let ids):
            let set = Set(ids)
            return devices.filter { set.contains($0.uniqueIdentifier) }
        }
    }
}

/// Reusable drill-down screen showing a filtered list of devices.
/// Pushed within the Dashboard's NavigationStack; presents DeviceDetailView as a sheet on row tap.
struct DeviceFilterView: View {
    @Environment(MeshViewModel.self) private var viewModel
    let spec: DeviceFilterSpec
    @State private var selectedDevice: ThreadDevice?

    /// Live-resolved from the shared view model so offline/weak membership tracks
    /// the poll loop rather than showing the set captured when the row was tapped.
    private var devices: [ThreadDevice] { spec.resolve(from: viewModel.devices) }

    var body: some View {
        Group {
            if devices.isEmpty {
                ContentUnavailableView(
                    "No Devices",
                    systemImage: "network",
                    description: Text("No devices match this category right now.")
                )
            } else {
                List {
                    ForEach(devices) { device in
                        Button { selectedDevice = device } label: {
                            DeviceListRow(device: device)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .navigationTitle(spec.title)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedDevice) { device in
            DeviceDetailView(device: device)
        }
    }
}
