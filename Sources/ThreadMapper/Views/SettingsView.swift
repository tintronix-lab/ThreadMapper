import SwiftUI
import UserNotifications

struct SettingsView: View {
    @AppStorage("notifyOffline")        private var notifyOffline = true
    @AppStorage("notifyTopology")       private var notifyTopology = true
    @AppStorage("notifyHealthDrop")     private var notifyHealthDrop = true
    @AppStorage("notifyWeeklyReport")   private var notifyWeeklyReport = true
    @AppStorage("notifyNewDevice")      private var notifyNewDevice = true
    @AppStorage("notifyProactiveAI")    private var notifyProactiveAI = true
    @AppStorage("offlineGracePeriod")   private var offlineGracePeriod = 60.0
    @AppStorage("demoMode")             private var demoMode = false
    @AppStorage("quietHoursEnabled")    private var quietHoursEnabled = false
    @AppStorage("quietHoursStart")      private var quietHoursStart = 22
    @AppStorage("quietHoursEnd")        private var quietHoursEnd = 7
    @AppStorage("borderRouterURL")      private var borderRouterURL = ""

    @State private var brTesting = false
    @State private var brTestResult: Bool?

    @Environment(DeviceStatsStore.self)   private var statsStore
    @Environment(HealthHistoryStore.self) private var historyStore
    @Environment(ActivityStore.self)      private var activityStore
    @State private var notificationService = NotificationService.shared

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
                borderRouterSection
                dataSection
                toolsSection
                aboutSection
                #if DEBUG
                debugSection
                #endif
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
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
        Section {
            if !notificationService.isAuthorized {
                Button {
                    UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
                } label: {
                    Label("Enable in iOS Settings", systemImage: "bell.slash.fill")
                        .foregroundStyle(.orange)
                }
            }
            Toggle("Offline device alerts", isOn: $notifyOffline)
                .disabled(!notificationService.isAuthorized)
            Picker("Offline grace period", selection: $offlineGracePeriod) {
                ForEach(gracePeriodOptions, id: \.seconds) { opt in
                    Text(opt.label).tag(opt.seconds)
                }
            }
            .disabled(!notifyOffline || !notificationService.isAuthorized)
            Toggle("Network topology changes", isOn: $notifyTopology)
                .disabled(!notificationService.isAuthorized)
            Toggle("Mesh health grade changes", isOn: $notifyHealthDrop)
                .disabled(!notificationService.isAuthorized)
            Toggle("New device detected", isOn: $notifyNewDevice)
                .disabled(!notificationService.isAuthorized)
            Toggle("Proactive AI insights", isOn: $notifyProactiveAI)
                .disabled(!notificationService.isAuthorized)
            Toggle("Weekly network report", isOn: $notifyWeeklyReport)
                .disabled(!notificationService.isAuthorized)
                .onChange(of: notifyWeeklyReport) { _, enabled in
                    if enabled {
                        Task {
                            await NotificationService.shared.scheduleWeeklyReportWithAIHeadline(
                                devices: [],
                                health: NetworkHealthScore.compute(devices: []),
                                historyEntries: historyStore.entries
                            )
                        }
                    } else {
                        UNUserNotificationCenter.current()
                            .removePendingNotificationRequests(withIdentifiers: ["weekly-report"])
                    }
                }
        } header: {
            Text("Notifications")
        } footer: {
            if notificationService.isAuthorized {
                Text("Grade drop alerts fire when your network health falls by one letter grade or more. Offline alerts wait for the grace period before firing. Weekly report arrives Sunday mornings.")
            } else {
                Text("ThreadMapper needs notification permission to alert you about device and network events.")
            }
        }
        .task { await notificationService.refreshAuthStatus() }
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
    private var borderRouterSection: some View {
        Section {
            TextField("http://192.168.1.50:8081", text: $borderRouterURL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.URL)
                .onChange(of: borderRouterURL) { _, _ in brTestResult = nil }
            if !borderRouterURL.isEmpty {
                Button {
                    Task { await testBorderRouter() }
                } label: {
                    HStack {
                        Text("Test Connection")
                        Spacer()
                        if brTesting {
                            ProgressView()
                        } else if let ok = brTestResult {
                            Image(systemName: ok ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundStyle(ok ? .green : .red)
                        }
                    }
                }
                .disabled(brTesting)
            }
        } header: {
            Text("Border Router")
        } footer: {
            Text("Advanced: connect an OpenThread Border Router's REST API to read real Thread network facts (channel, PAN ID) and improve link quality readings. Changes apply immediately. Apple/Google border routers don't expose this; OTBR-based ones (e.g. Home Assistant) do.")
        }
    }

    private func testBorderRouter() async {
        guard let url = URL(string: borderRouterURL) else { brTestResult = false; return }
        brTesting = true
        let ok = await BorderRouterClient(baseURL: url).testConnection()
        brTesting = false
        brTestResult = ok
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
            NavigationLink {
                UserManualView()
            } label: {
                Label("User Manual", systemImage: "book.pages")
            }
            Button {
                UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
            } label: {
                Label("Language", systemImage: "globe")
                    .foregroundStyle(.primary)
            }
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
