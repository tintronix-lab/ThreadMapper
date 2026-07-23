import SwiftUI

/// Aggregated device history derived from ActivityStore events.
/// Shows when each device was first and last seen, and how often it disconnected.
struct DeviceHistoryView: View {
    @ScaledMetric(relativeTo: .caption2) private var microLabelSize: CGFloat = 9
    @Environment(ActivityStore.self) private var activityStore
    @Environment(MeshViewModel.self) private var meshViewModel

    private struct DeviceRecord: Identifiable {
        let id: UUID
        let name: String
        let firstSeen: Date
        let lastActivity: Date
        let joinCount: Int
        let offlineCount: Int
        let isCurrentlyOnline: Bool

        var stabilityGrade: String {
            guard joinCount > 0 else { return "?" }
            // Stability = how infrequently it goes offline relative to being known
            if offlineCount == 0 { return "A" }
            let ratio = Double(offlineCount) / Double(max(joinCount, 1))
            if ratio < 0.1 { return "B" }
            if ratio < 0.3 { return "C" }
            if ratio < 0.6 { return "D" }
            return "F"
        }

        var stabilityColor: Color {
            switch stabilityGrade {
            case "A": return .green
            case "B": return .mint
            case "C": return .yellow
            case "D": return .orange
            default:  return .red
            }
        }
    }

    private var records: [DeviceRecord] {
        let events = activityStore.events
        guard !events.isEmpty else { return [] }

        // Gather all device IDs we've seen (prefer non-nil deviceID for grouping)
        var joinDates: [UUID: Date] = [:]
        var lastDates: [UUID: Date] = [:]
        var joinCounts: [UUID: Int] = [:]
        var offlineCounts: [UUID: Int] = [:]
        var nameByID: [UUID: String] = [:]

        for event in events {
            guard let devID = event.deviceID else { continue }
            if let name = event.deviceName { nameByID[devID] = name }

            if joinDates[devID] == nil || event.timestamp < joinDates[devID]! {
                joinDates[devID] = event.timestamp
            }
            if lastDates[devID] == nil || event.timestamp > lastDates[devID]! {
                lastDates[devID] = event.timestamp
            }
            if event.kind == .topologyJoined { joinCounts[devID, default: 0] += 1 }
            if event.kind == .deviceOffline { offlineCounts[devID, default: 0] += 1 }
        }

        let onlineIDs = Set(meshViewModel.devices.filter { !$0.isOffline }.map(\.id))

        return joinDates.keys.compactMap { id in
            guard let first = joinDates[id], let last = lastDates[id],
                  let name = nameByID[id] else { return nil }
            return DeviceRecord(
                id: id,
                name: name,
                firstSeen: first,
                lastActivity: last,
                joinCount: joinCounts[id] ?? 0,
                offlineCount: offlineCounts[id] ?? 0,
                isCurrentlyOnline: onlineIDs.contains(id)
            )
        }.sorted { $0.firstSeen < $1.firstSeen }
    }

    var body: some View {
        Group {
            if records.isEmpty {
                emptyState
            } else {
                List {
                    summaryHeader
                    ForEach(records) { record in
                        recordRow(record)
                    }
                }
            }
        }
        .navigationTitle("Device History")
        .navigationBarTitleDisplayMode(.large)
    }

    // MARK: - Summary

    @ViewBuilder
    private var summaryHeader: some View {
        Section {
            HStack(spacing: 0) {
                summaryCell(value: "\(records.count)", label: "Devices Seen", color: .primary)
                Divider().frame(height: 36)
                summaryCell(
                    value: "\(records.filter { $0.offlineCount == 0 }.count)",
                    label: "Never Offline",
                    color: .green
                )
                Divider().frame(height: 36)
                summaryCell(
                    value: "\(records.filter { $0.offlineCount >= 3 }.count)",
                    label: "Unstable",
                    color: records.contains { $0.offlineCount >= 3 } ? .red : .secondary
                )
            }
            .padding(.vertical, 4)
        } footer: {
            Text("Based on 7 days of recorded activity. Stability grade reflects how often a device goes offline relative to how many times it has re-joined the mesh.")
                .font(.caption)
        }
    }

    private func summaryCell(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.title2.weight(.bold).monospacedDigit())
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Record row

    @ViewBuilder
    private func recordRow(_ record: DeviceRecord) -> some View {
        HStack(spacing: 14) {
            // Stability grade badge
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(record.stabilityColor.opacity(0.12))
                    .frame(width: 44, height: 44)
                Text(record.stabilityGrade)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(record.stabilityColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(record.name)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    if record.isCurrentlyOnline {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 6, height: 6)
                    }
                }
                HStack(spacing: 10) {
                    Label(record.firstSeen.formatted(.dateTime.month().day()), systemImage: "calendar")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    if record.offlineCount > 0 {
                        Label("\(record.offlineCount) offline", systemImage: "wifi.slash")
                            .font(.caption2)
                            .foregroundStyle(record.offlineCount >= 3 ? .red : .orange)
                    } else {
                        Label("Never offline", systemImage: "checkmark.circle")
                            .font(.caption2)
                            .foregroundStyle(.green)
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(record.lastActivity, style: .relative)
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.tertiary)
                Text("last event")
                    .font(.system(size: microLabelSize))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 2)
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.largeTitle)
                .foregroundStyle(.tertiary)
            Text("No History Yet")
                .font(.headline)
            Text("ThreadMapper records device events as your network changes. Check back after devices have joined, left, or gone offline.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
