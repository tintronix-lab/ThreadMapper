import SwiftUI
import SwiftData

@main
struct ThreadMapperApp: App {
    let modelContainer: ModelContainer

    init() {
        let schema = Schema([ThreadDevice.self, MeshLink.self, SurveyPoint.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            modelContainer = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("SwiftData model container failed: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            DashboardView()
                .modelContainer(modelContainer)
        }
    }
}
