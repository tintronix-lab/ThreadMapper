import SwiftUI

struct DeviceListRow: View {
    let device: ThreadDevice
    @Environment(DeviceStatsStore.self) private var statsStore

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            signalIcon
                .frame(width: 20, height: 20)
            VStack(alignment: .leading, spacing: 1) {
                Text(device.name)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(typeLabel)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    if let room = device.room {
                        Text("· \(room)")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                    if let batt = device.batteryPercentage {
                        Label("\(batt)%", systemImage: batt > 20 ? "battery.75" : "battery.25")
                            .font(.caption2)
                            .foregroundStyle(batt > 20 ? Color.secondary : Color.red)
                            .labelStyle(.titleAndIcon)
                    }
                }
            }
            Spacer(minLength: 4)
            VStack(alignment: .trailing, spacing: 2) {
                if let rssi = device.rssi {
                    Text("\(rssi) dBm")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(rssi.rssiColor)
                }
                if let stats = statsStore.stats(for: device.uniqueIdentifier) {
                    Text(stats.healthGrade)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(stats.healthColor)
                        .frame(minWidth: 14, alignment: .trailing)
                }
            }
        }
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill((device.rssi ?? 0) < -80 ? Color.red.opacity(0.05) : Color.clear)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
    }

    @ViewBuilder
    private var signalIcon: some View {
        Image(systemName: device.rssi.rssiSystemIcon)
            .foregroundStyle(device.rssi.rssiColor)
            .imageScale(.small)
    }

    private var typeLabel: String {
        if device.isBorderRouter { return "Border Router" }
        if device.isRouter { return "Router" }
        return device.deviceType
    }

    private var accessibilityDescription: String {
        var parts = [device.name, typeLabel]
        if let rssi = device.rssi { parts.append("\(rssi.rssiQualityLabel) signal at \(rssi) dBm") }
        if let room = device.room { parts.append("in \(room)") }
        if let batt = device.batteryPercentage { parts.append("battery \(batt)%") }
        return parts.joined(separator: ", ")
    }
}
