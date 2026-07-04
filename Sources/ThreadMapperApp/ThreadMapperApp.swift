import SwiftUI
import Observation

@main
struct ThreadMapperApp: App {
    init() {
        // Must be registered before app finishes launching
        BackgroundRefreshHandler.register()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
