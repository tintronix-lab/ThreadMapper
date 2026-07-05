import SwiftUI

struct SettingsView: View {
    @AppStorage("notifyOffline")        private var notifyOffline = true
    @AppStorage("notifyTopology")       private var notifyTopology = true
    @AppStorage("offlineGracePeriod")   private var offlineGracePeriod = 60.0
    @AppStorage("demoMode")             private var demoMode = false
    @AppStorage("quietHoursEnabled")    private var quietHoursEnabled = false
    @AppStorage("quietHoursStart")      private var quietHoursStart = 22
    @AppStorage("quietHoursEnd")        private var quietHoursEnd = 7

    @Environment(DeviceStatsStore.self)   private var statsStore
    @Environment(HealthHistoryStore.self) private var historyStore
    @Environment(ActivityStore.self)      private var activityStore

    @State private var showClearStatsConfirm    = false
    @State private var showClearHistoryConfirm  = false
    @State private var showClearActivityConfirm = false
    #if DEBUG
    @State private var showPaywallPreview = false
    #endif

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
                quietHoursSection
                alertsSection
                dataSection
                toolsSection
                aboutSection
                #if DEBUG
                debugSection
                #endif
            }
            .navigationTitle("Settings")
            #if DEBUG
            .sheet(isPresented: $showPaywallPreview) { PaywallView() }
            #endif
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var toolsSection: some View {
        Section {
            NavigationLink("Setup Checklist") {
                AppChecklistView()
            }
            Toggle(isOn: $demoMode) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Demo Mode")
                    Text("Simulates a Thread network — no HomeKit required. Restart the app to apply.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("Tools")
        }
    }

    @ViewBuilder
    private var notificationsSection: some View {
        Section("Notifications") {
            Toggle("Offline device alerts", isOn: $notifyOffline)
            Toggle("Network topology changes", isOn: $notifyTopology)
        }
    }

    @ViewBuilder
    private var quietHoursSection: some View {
        Section {
            Toggle("Enable Quiet Hours", isOn: $quietHoursEnabled)
            if quietHoursEnabled {
                Picker("Start", selection: $quietHoursStart) {
                    ForEach(0..<24, id: \.self) { hour in
                        Text(hourLabel(hour)).tag(hour)
                    }
                }
                Picker("End", selection: $quietHoursEnd) {
                    ForEach(0..<24, id: \.self) { hour in
                        Text(hourLabel(hour)).tag(hour)
                    }
                }
            }
        } header: {
            Text("Quiet Hours")
        } footer: {
            if quietHoursEnabled {
                let label = quietHoursStart <= quietHoursEnd
                    ? "\(hourLabel(quietHoursStart)) – \(hourLabel(quietHoursEnd))"
                    : "\(hourLabel(quietHoursStart)) – midnight – \(hourLabel(quietHoursEnd))"
                Text("Notifications are suppressed \(label).")
            } else {
                Text("Suppress all alerts during a nightly window.")
            }
        }
    }

    private func hourLabel(_ hour: Int) -> String {
        let d = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: Date()) ?? Date()
        return d.formatted(.dateTime.hour(.defaultDigits(amPM: .abbreviated)))
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
                    statsStore.clearAll()
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

    #if DEBUG
    @ViewBuilder
    private var debugSection: some View {
        Section {
            Button("Preview Paywall") {
                showPaywallPreview = true
            }
        } header: {
            Text("Debug")
        } footer: {
            Text("Debug-only. Not visible in release builds.")
        }
    }
    #endif

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
