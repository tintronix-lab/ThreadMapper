import SwiftUI

/// Sheet showing firmware version change log for a single device.
struct FirmwareHistorySheet: View {
    let device: ThreadDevice
    @Environment(\.dismiss) private var dismiss

    private var changes: [FirmwareChange] {
        FirmwareHistoryStore.shared.changes(for: device.uniqueIdentifier)
    }

    var body: some View {
        NavigationStack {
            Group {
                if changes.isEmpty {
                    ContentUnavailableView(
                        "No Version Changes",
                        systemImage: "clock.arrow.trianglehead.counterclockwise.rotate.90",
                        description: Text("ThreadMapper records a change entry whenever the firmware version reported by HomeKit differs from the previously known version.")
                    )
                } else {
                    List {
                        if let current = device.firmwareVersion {
                            Section("Current") {
                                LabeledContent("Version") {
                                    Text(current)
                                        .font(.subheadline.monospacedDigit().weight(.semibold))
                                }
                            }
                        }
                        Section("Change Log") {
                            ForEach(changes) { change in
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        if let from = change.fromVersion {
                                            Text(from)
                                                .font(.caption.monospacedDigit())
                                                .foregroundStyle(.secondary)
                                            Image(systemName: "arrow.right")
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        }
                                        Text(change.toVersion)
                                            .font(.caption.monospacedDigit().weight(.semibold))
                                            .foregroundStyle(.primary)
                                    }
                                    Text(change.detectedAt, style: .date)
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                                .padding(.vertical, 2)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Firmware History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
