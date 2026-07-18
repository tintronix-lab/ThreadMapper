import SwiftUI
import Charts

extension NetworkDiagnosticsView {
    // MARK: - Protocol Compatibility Section

    @ViewBuilder
    func compatibilityOverviewSection(_ devices: [ThreadDevice]) -> some View {
        let grouped = Dictionary(grouping: devices, by: \.deviceProtocol)
        let order: [DeviceProtocol] = [.threadBorderRouter, .threadNative, .matterBridge, .zigbeeBridge, .homeKitOnly, .unknown]
        let zigbeeBridgeCount = (grouped[.zigbeeBridge] ?? []).count
        let nonThreadCount = (grouped[.homeKitOnly] ?? []).count + (grouped[.matterBridge] ?? []).count

        Section {
            ForEach(order, id: \.self) { proto in
                if let group = grouped[proto], !group.isEmpty {
                    HStack(spacing: 12) {
                        Image(systemName: proto.icon)
                            .foregroundStyle(proto.color)
                            .frame(width: 22)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(proto.shortLabel)
                                .font(.subheadline.weight(.medium))
                            Text(group.map(\.name).joined(separator: ", "))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                        Spacer()
                        Text("\(group.count)")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(proto.color)
                    }
                    .padding(.vertical, 2)
                }
            }
            if zigbeeBridgeCount > 0 {
                Label("^[\(zigbeeBridgeCount) Zigbee bridge](inflect: true) detected — devices behind these hubs are not on your Thread mesh", systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .padding(.vertical, 2)
            }
            if nonThreadCount > 0 {
                Label("^[\(nonThreadCount) device](inflect: true) connected via HomeKit only — consider Thread-native replacements for better mesh coverage", systemImage: "info.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 2)
            }
        } header: {
            HStack {
                Text("Protocol Compatibility")
                Spacer()
                let threadCount = (grouped[.threadBorderRouter] ?? []).count + (grouped[.threadNative] ?? []).count
                Text("\(threadCount) of \(devices.count) Thread")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Firmware Overview Section

    @ViewBuilder
    func firmwareOverviewSection(_ devices: [ThreadDevice]) -> some View {
        let withFirmware = devices.filter { $0.firmwareVersion != nil }
        if !withFirmware.isEmpty {
            let recentChanges = FirmwareHistoryStore.shared.changes.prefix(5)
            Section {
                ForEach(withFirmware.sorted { ($0.firmwareVersion ?? "") < ($1.firmwareVersion ?? "") }, id: \.uniqueIdentifier) { device in
                    HStack(spacing: 10) {
                        Image(systemName: device.deviceProtocol.icon)
                            .foregroundStyle(device.deviceProtocol.color)
                            .frame(width: 20)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(device.name)
                                .font(.subheadline)
                                .lineLimit(1)
                            if let room = device.room {
                                Text(room)
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        Spacer()
                        Text(device.firmwareVersion ?? "—")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 1)
                }
                if !recentChanges.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Recent Updates")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        ForEach(recentChanges) { change in
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.up.circle.fill")
                                    .font(.caption2)
                                    .foregroundStyle(.green)
                                Text(change.deviceName)
                                    .font(.caption)
                                if let from = change.fromVersion {
                                    Text("\(from) → \(change.toVersion)")
                                        .font(.caption.monospacedDigit())
                                        .foregroundStyle(.secondary)
                                } else {
                                    Text(change.toVersion)
                                        .font(.caption.monospacedDigit())
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(change.detectedAt, style: .relative)
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            } header: {
                HStack {
                    Text("Firmware Versions")
                    Spacer()
                    Text("\(withFirmware.count) of \(devices.count) reported")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } footer: {
                Text("Firmware versions are reported by HomeKit and may not reflect the latest available update from each manufacturer.")
                    .font(.caption)
            }
        }
    }
}
