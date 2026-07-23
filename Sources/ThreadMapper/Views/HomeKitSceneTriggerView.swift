import SwiftUI

// MARK: - NF-7: HomeKit Scene Trigger Settings View

struct HomeKitSceneTriggerView: View {
    @State private var store = HomeKitSceneTriggerStore.shared

    var body: some View {
        Form {
            Section {
                Toggle("Enable Scene Trigger", isOn: $store.isEnabled)
                    .onChange(of: store.isEnabled) { _, enabled in
                        if enabled { store.loadScenes() }
                    }
            } footer: {
                Text("Automatically run a HomeKit scene when your network health drops below a chosen grade.")
            }

            if store.isEnabled {
                thresholdSection
                scenePickerSection
                infoSection
            }
        }
        .navigationTitle("Scene Trigger")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { if store.isEnabled { store.loadScenes() } }
    }

    @ViewBuilder
    private var thresholdSection: some View {
        Section("Trigger Threshold") {
            Picker("Fire when grade drops to", selection: $store.triggerGrade) {
                Text("C — Fair (60–74)").tag("C")
                Text("D — Poor (40–59)").tag("D")
                Text("F — Critical (<40)").tag("F")
            }
            .pickerStyle(.inline)
        }
    }

    @ViewBuilder
    private var scenePickerSection: some View {
        Section(header: Text("HomeKit Scene"),
                footer: store.actionSetName.isEmpty ? Text("") : Text("Selected: \(store.actionSetName)")) {
            if store.isLoadingScenes {
                HStack {
                    ProgressView()
                    Text("Loading scenes…").foregroundStyle(.secondary)
                }
            } else if store.availableActionSets.isEmpty {
                Text("No scenes found. Create scenes in the Home app first.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(store.availableActionSets) { info in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(info.name)
                            Text(info.homeName).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if store.actionSetUUID == info.id {
                            Image(systemName: "checkmark").foregroundStyle(.blue)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        store.actionSetUUID = info.id
                        store.actionSetName = info.name
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var infoSection: some View {
        Section {
            HStack(spacing: 8) {
                Image(systemName: "info.circle").foregroundStyle(.blue)
                Text("The scene runs once each time health crosses the threshold from above.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
