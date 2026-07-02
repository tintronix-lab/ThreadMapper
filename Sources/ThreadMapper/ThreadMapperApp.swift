import SwiftUI

@main
struct ThreadMapperApp: App {
    init() {}

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                ContentView()
            }
        }
    }
}

struct ContentView: View {
    @State private var viewModel = MeshViewModel()

    var body: some View {
        DashboardView()
            .sheet(item: $viewModel.selectedDevice) { device in
                DeviceDetailView(device: device)
            }
            .environment(viewModel)
    }
}
