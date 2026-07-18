import SwiftUI

struct AppChecklistView: View {
    @Environment(MeshViewModel.self) private var meshVM
    @Environment(SurveyViewModel.self) private var surveyVM

    // No inner NavigationStack — this view is pushed from Settings.
    var body: some View {
        List {
                Section("Setup") {
                    checkRow(
                        label: "Thread Devices",
                        value: meshVM.devices.isEmpty ? "None found" : "^[\(meshVM.devices.count) device](inflect: true) found",
                        ok: !meshVM.devices.isEmpty
                    )
                    checkRow(
                        label: "Border Router",
                        value: hasBorderRouter ? "Detected" : "Not detected",
                        ok: hasBorderRouter
                    )
                    checkRow(
                        label: "Routers",
                        value: "\(routerCount)",
                        ok: routerCount > 0
                    )
                }

                Section("Signal Health") {
                    checkRow(
                        label: "Weak devices",
                        value: weakCount == 0 ? "None" : "^[\(weakCount) device](inflect: true)",
                        ok: weakCount == 0
                    )
                    checkRow(
                        label: "Low battery",
                        value: lowBatteryCount == 0 ? "None" : "^[\(lowBatteryCount) device](inflect: true)",
                        ok: lowBatteryCount == 0
                    )
                }

                Section("Survey Data") {
                    checkRow(
                        label: "Saved surveys",
                        value: surveyVM.savedPointCount == 0 ? "None" : "\(surveyVM.savedPointCount)",
                        ok: surveyVM.savedPointCount > 0
                    )
                    checkRow(
                        label: "Weak links recorded",
                        value: surveyVM.hasWeakDevices ? "^[\(surveyVM.weakDevices.count) device](inflect: true)" : "None",
                        ok: !surveyVM.hasWeakDevices
                    )
                }

                if !meshVM.warnings().isEmpty {
                    Section("Warnings") {
                        ForEach(meshVM.warnings(), id: \.self) { warning in
                            Label(warning, systemImage: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                                .font(.subheadline)
                        }
                    }
                }
        }
        .navigationTitle("Checklist")
    }

    private var hasBorderRouter: Bool {
        meshVM.devices.contains { $0.isBorderRouter }
    }

    private var routerCount: Int {
        meshVM.devices.filter(\.isRoutingCapable).count
    }

    private var weakCount: Int {
        // nil RSSI intentionally counts as weak here (unmeasured ⇒ assume worst)
        meshVM.devices.filter { ($0.rssi ?? SignalThresholds.offlineSentinel).isWeakRSSI }.count
    }

    private var lowBatteryCount: Int {
        meshVM.devices.filter { ($0.batteryPercentage ?? 100) < 20 }.count
    }

    @ViewBuilder
    private func checkRow(label: LocalizedStringKey, value: LocalizedStringKey, ok: Bool) -> some View {
        HStack {
            Image(systemName: ok ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .foregroundStyle(ok ? .green : .orange)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.body)
                Text(value)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
