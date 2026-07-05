import SwiftUI

struct SettingsView: View {
    @AppStorage("notifyOffline")        private var notifyOffline = true
    @AppStorage("notifyTopology")       private var notifyTopology = true
    @AppStorage("offlineGracePeriod")   private var offlineGracePeriod = 60.0

    @Environment(DeviceStatsStore.self)   private var statsStore
    @Environment(HealthHistoryStore.self) private var historyStore
    @Environment(ActivityStore.self)      private var activityStore

    @State private var showClearStatsConfirm    = false
    @State private var showClearHistoryConfirm  = false
    @State private var showClearActivityConfirm = false

    private let gracePeriodOptions: [(label: String, seconds: Double)] = [
        ("30 seconds",  30),
        ("1 minute",    60),
        ("2 minutes",  120),
        ("5 minutes",  300),
    ]

    var body: some View {
        NavigationStack {
            Form {
                notificationsSection
                alertsSection
                dataSection
                aboutSection
            }
            .navigationTitle("Settings")
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var notificationsSection: some View {
        Section("Notifications") {
            Toggle("Offline device alerts", isOn: $notifyOffline)
            Toggle("Network topology changes", isOn: $notifyTopology)
        }
    }

    @ViewBuilder
    private var alertsSection: some View {
        Section {
            Picker("Offline grace period", selection: $offlineGracePeriod) {
                ForEach(gracePeriodOptions, id: \.seconds) { opt in
                    Text(opt.label).tag(opt.seconds)
                }
            }
        } header: {
            Text("Alerts")
        } footer: {
            Text("How long a device must be unreachable before an offline alert fires.")
        }
    }

    @ViewBuilder
    private var dataSection: some View {
        Section("Data") {
            Button("Clear Signal History", role: .destructive) {
                showClearStatsConfirm = true
            }
            .confirmationDialog(
                "Clear all stored per-device signal readings?",
                isPresented: $showClearStatsConfirm,
                titleVisibility: .visible
            ) {
                Button("Clear All Signal Data", role: .destructive) {
                    let keys = Array(statsStore.readings.keys)
                    for key in keys { statsStore.clear(for: key) }
                }
            }

            Button("Clear Health Score History", role: .destructive) {
                showClearHistoryConfirm = true
            }
            .confirmationDialog(
                "Clear the 24-hour health score history?",
                isPresented: $showClearHistoryConfirm,
                titleVisibility: .visible
            ) {
                Button("Clear History", role: .destructive) {
                    historyStore.clearAll()
                }
            }

            Button("Clear Activity Feed", role: .destructive) {
                showClearActivityConfirm = true
            }
            .confirmationDialog(
                "Clear all activity events?",
                isPresented: $showClearActivityConfirm,
                titleVisibility: .visible
            ) {
                Button("Clear Activity", role: .destructive) {
                    activityStore.clearAll()
                }
            }
        }
    }

    @ViewBuilder
    private var aboutSection: some View {
        Section("About") {
            LabeledContent("Version") {
                Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—")
                    .foregroundStyle(.secondary)
            }
            LabeledContent("Build") {
                Text(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—")
                    .foregroundStyle(.secondary)
            }
        }
    }
}
