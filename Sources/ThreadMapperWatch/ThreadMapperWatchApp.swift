import SwiftUI

@main
struct ThreadMapperWatchApp: App {
    @StateObject private var store = WatchConnectivityStore()

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                WatchDashboardView()
            }
            .environmentObject(store)
        }
    }
}
