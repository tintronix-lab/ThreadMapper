import SwiftUI

/// Navigation value pushed onto DashboardView's NavigationPath to drill into a filtered device list.
struct DeviceFilterSpec: Hashable {
    let title: String
    let devices: [ThreadDevice]
}

/// Reusable drill-down screen showing a filtered list of devices.
/// Pushed within the Dashboard's NavigationStack; presents DeviceDetailView as a sheet on row tap.
struct DeviceFilterView: View {
    let spec: DeviceFilterSpec
    @State private var selectedDevice: ThreadDevice?

    var body: some View {
        Group {
            if spec.devices.isEmpty {
                ContentUnavailableView(
                    "No Devices",
                    systemImage: "network",
                    description: Text("No devices match this category right now.")
                )
            } else {
                List {
                    ForEach(spec.devices) { device in
                        DeviceListRow(device: device)
                            .contentShape(Rectangle())
                            .onTapGesture { selectedDevice = device }
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
