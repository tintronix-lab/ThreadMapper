import SwiftUI

struct CommissioningReadinessView: View {
    @ScaledMetric(relativeTo: .title) private var statusIconSize: CGFloat = 28
    let devices: [ThreadDevice]

    @Environment(\.dismiss) private var dismiss
    @State private var checks: [CommissioningCheck] = []
    @State private var isComputing = true

    private struct CommissioningCheck: Identifiable {
        let id = UUID()
        let title: LocalizedStringResource
        let detail: LocalizedStringResource
        let status: Status
        let icon: String

        enum Status {
            case pass, warning, fail

            var color: Color {
                switch self { case .pass: .green; case .warning: .orange; case .fail: .red }
            }
            var icon: String {
                switch self { case .pass: "checkmark.circle.fill"; case .warning: "exclamationmark.triangle.fill"; case .fail: "xmark.circle.fill" }
            }
            var label: LocalizedStringResource {
                switch self { case .pass: "Pass"; case .warning: "Warning"; case .fail: "Fail" }
            }
        }
    }

    private var overallStatus: CommissioningCheck.Status {
        if checks.contains(where: { $0.status == .fail }) { return .fail }
        if checks.contains(where: { $0.status == .warning }) { return .warning }
        return .pass
    }

    var body: some View {
        NavigationStack {
            Group {
                if isComputing {
                    VStack(spacing: 16) {
                        ProgressView()
                            .controlSize(.large)
                        Text("Running readiness checks…")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        overallSection
                        checksSection
                        adviceSection
                    }
                }
            }
            .navigationTitle("Commissioning Readiness")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .task { computeChecks() }
    }

    // MARK: - Sections

    private var overallSection: some View {
        Section {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(overallStatus.color.opacity(0.12))
                        .frame(width: 64, height: 64)
                    Image(systemName: overallStatus.icon)
                        .font(.system(size: statusIconSize))
                        .foregroundStyle(overallStatus.color)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(overallHeadline)
                        .font(.headline)
                    Text(overallSubheadline)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.vertical, 6)
        }
    }

    private var overallHeadline: LocalizedStringResource {
        switch overallStatus {
        case .pass:    return "Ready to Commission"
        case .warning: return "Ready with Caveats"
        case .fail:    return "Not Ready"
        }
    }

    private var overallSubheadline: LocalizedStringResource {
        let fails = checks.filter { $0.status == .fail }.count
        let warns = checks.filter { $0.status == .warning }.count
        switch overallStatus {
        case .pass:    return "Your Thread network passed all checks. You can safely add a new device."
        case .warning: return "^[\(warns) warning](inflect: true) found. New devices should work, but consider resolving these for the best experience."
        case .fail:    return "^[\(fails) critical issue](inflect: true) must be resolved before commissioning."
        }
    }

    @ViewBuilder
    private var checksSection: some View {
        Section("Checks") {
            ForEach(checks) { check in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: check.status.icon)
                        .foregroundStyle(check.status.color)
                        .frame(width: 20)
                        .padding(.top, 1)
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(check.title)
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            Text(check.status.label)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(check.status.color)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(check.status.color.opacity(0.12), in: Capsule())
                        }
                        Text(check.detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.vertical, 3)
            }
        }
    }

    @ViewBuilder
    private var adviceSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 10) {
                Label("How to Commission a Thread Device", systemImage: "lightbulb.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .symbolRenderingMode(.multicolor)
                ForEach([
                    "Ensure the device is powered on and in pairing mode (usually indicated by a blinking light).",
                    "Open the Home app on your iPhone or iPad.",
                    "Tap + → Add Accessory, then scan the QR code or enter the setup code.",
                    "Follow the on-screen steps — HomeKit will handle Thread commissioning automatically.",
                    "If commissioning fails, verify your border router is reachable and try moving the device closer.",
                ], id: \.self) { step in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "arrow.right.circle")
                            .font(.caption)
                            .foregroundStyle(.blue)
                            .padding(.top, 1)
                        Text(step)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(.vertical, 4)
        } header: {
            Text("Commissioning Guide")
        }
    }

    // MARK: - Check computation

    private func computeChecks() {
        let report = NetworkDiagnosticsEngine.analyze(devices: devices)

        let borderRouters = devices.filter(\.isBorderRouter)
        let offline = devices.filter(\.isOffline)
        let deepDevices = report.deviceHops.filter { $0.hopCount >= 4 && !$0.device.isOffline }
        let conflictChannels = report.channelStats.filter { $0.interferenceRisk == .high }
        let routers = devices.filter(\.isRoutingCapable)

        checks = [
            // Border router present
            CommissioningCheck(
                title: "Border Router Present",
                detail: borderRouters.isEmpty
                    ? "No border router detected. Add a HomePod mini, HomePod, or Apple TV 4K to enable Thread commissioning."
                    : "^[\(borderRouters.count) border router](inflect: true) found: \(borderRouters.prefix(2).map(\.name).joined(separator: ", "))\(borderRouters.count > 2 ? "…" : "").",
                status: borderRouters.isEmpty ? .fail : .pass,
                icon: "antenna.radiowaves.left.and.right"
            ),

            // Redundant border routers
            CommissioningCheck(
                title: "Border Router Redundancy",
                detail: borderRouters.count >= 2
                    ? "\(borderRouters.count) border routers provide failover if one goes offline."
                    : "Only one border router. If it goes offline, the entire mesh loses internet. Consider adding a second.",
                status: borderRouters.count >= 2 ? .pass : .warning,
                icon: "arrow.left.arrow.right"
            ),

            // No offline devices blocking
            CommissioningCheck(
                title: "Mesh Reachability",
                detail: offline.isEmpty
                    ? "All ^[\(devices.count) device](inflect: true) are online and reachable."
                    : "^[\(offline.count) device](inflect: true) offline: \(offline.prefix(2).map(\.name).joined(separator: ", "))\(offline.count > 2 ? "…" : ""). Offline devices can fragment the mesh.",
                status: offline.isEmpty ? .pass : (offline.count <= 2 ? .warning : .fail),
                icon: "wifi"
            ),

            // Routing capacity
            CommissioningCheck(
                title: "Routing Capacity",
                detail: routers.count >= 3
                    ? "^[\(routers.count) routing device](inflect: true) provide good mesh capacity for new devices."
                    : routers.count >= 1
                        ? "^[\(routers.count) routing device](inflect: true) available. More mains-powered Thread devices improve coverage."
                        : "No Thread routers detected. New devices will have limited routing options.",
                status: routers.count >= 3 ? .pass : (routers.count >= 1 ? .warning : .fail),
                icon: "point.3.connected.trianglepath.dotted"
            ),

            // Channel interference
            CommissioningCheck(
                title: "Thread Channel",
                detail: conflictChannels.isEmpty
                    ? "^[\(report.channelStats.count) Thread channel](inflect: true) have low Wi-Fi interference risk."
                    : "^[\(conflictChannels.count) channel](inflect: true) \(conflictChannels.map { "CH\($0.channel)" }.joined(separator: ", ")) overlap with 2.4 GHz Wi-Fi. Consider switching to CH 15, 20, or 25.",
                status: conflictChannels.isEmpty ? .pass : .warning,
                icon: "waveform.badge.exclamationmark"
            ),

            // Hop depth
            CommissioningCheck(
                title: "Mesh Depth",
                detail: deepDevices.isEmpty
                    ? "All reachable devices are within 3 hops of a border router."
                    : "^[\(deepDevices.count) device](inflect: true) at 4+ hops. New devices added near them may also land deep in the mesh.",
                status: deepDevices.isEmpty ? .pass : .warning,
                icon: "arrow.up.forward.circle"
            ),
        ]

        isComputing = false
    }
}
