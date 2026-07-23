import SwiftUI

// MARK: - NF-10: Mesh Topology Time-Lapse Rewind View

struct MeshTopologyRewindView: View {
    // Access the singleton directly — @Observable tracks changes automatically in body.
    // Using @State with a @MainActor-isolated singleton triggers an actor-isolation
    // crash in iOS 26's stricter concurrency mode.
    @State private var frameIndex = 0
    @State private var isPlaying = false
    @State private var playTask: Task<Void, Never>? = nil
    @Environment(\.dismiss) private var dismiss

    private var frames: [TimeLapseFrame] { TopologyTimeLapseStore.shared.frames }
    private var currentFrame: TimeLapseFrame? {
        guard !frames.isEmpty else { return nil }
        return frames[min(frameIndex, frames.count - 1)]
    }

    var body: some View {
        NavigationStack {
            Group {
                if frames.isEmpty {
                    emptyState
                } else {
                    content
                }
            }
            .navigationTitle("Topology Time-Lapse")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        stopPlay()
                        dismiss()
                    }
                }
            }
        }
        .onDisappear { stopPlay() }
    }

    @ViewBuilder
    private var content: some View {
        VStack(spacing: 0) {
            if let frame = currentFrame {
                FrameView(frame: frame)
            }

            Divider()

            VStack(spacing: 12) {
                // Only show scrubber when there are multiple frames
                if frames.count > 1 {
                    Slider(value: Binding(
                        get: { Double(frameIndex) },
                        set: { frameIndex = Int($0.rounded()) }
                    ), in: 0...Double(frames.count - 1), step: 1)
                    .padding(.horizontal)
                }

                if let frame = currentFrame {
                    Text(frame.timestamp.formatted(.dateTime.month().day().hour().minute()))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 24) {
                    Button {
                        frameIndex = max(0, frameIndex - 1)
                    } label: {
                        Image(systemName: "backward.fill")
                    }
                    .disabled(frameIndex == 0 || frames.count <= 1)

                    Button {
                        if isPlaying { stopPlay() } else { startPlay() }
                    } label: {
                        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                            .font(.title2)
                    }
                    .disabled(frames.count <= 1)

                    Button {
                        frameIndex = min(frames.count - 1, frameIndex + 1)
                    } label: {
                        Image(systemName: "forward.fill")
                    }
                    .disabled(frameIndex >= frames.count - 1)
                }
                .font(.title3)

                Text("\(frameIndex + 1) of \(frames.count) snapshots")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(Color(UIColor.systemGroupedBackground))
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("No Snapshots Yet")
                .font(.headline)
            Text("Snapshots are recorded automatically as your network changes. Come back in an hour to see the first replay.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @MainActor
    private func startPlay() {
        guard frames.count > 1 else { return }
        isPlaying = true
        playTask = Task { @MainActor in
            while !Task.isCancelled && isPlaying {
                try? await Task.sleep(for: .milliseconds(600))
                guard !Task.isCancelled else { break }
                if frameIndex < frames.count - 1 {
                    frameIndex += 1
                } else {
                    stopPlay()
                }
            }
        }
    }

    @MainActor
    private func stopPlay() {
        isPlaying = false
        playTask?.cancel()
        playTask = nil
    }
}

// MARK: - Single frame display

private struct FrameView: View {
    let frame: TimeLapseFrame

    private var sorted: [TimeLapseFrame.DeviceSnapshot] {
        frame.deviceSnapshots.sorted { $0.name < $1.name }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                HStack(spacing: 0) {
                    statCell("\(frame.totalCount)", label: "Total")
                    Divider().frame(height: 28)
                    statCell("\(frame.onlineCount)", label: "Online", color: .green)
                    Divider().frame(height: 28)
                    statCell("\(frame.offlineCount)", label: "Offline",
                             color: frame.offlineCount > 0 ? .red : .secondary)
                }
                .padding(.vertical, 10)
                .cardBackground()

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(sorted) { device in
                        DeviceFrameCard(device: device)
                    }
                }
            }
            .padding(16)
        }
        .background(Color(UIColor.systemGroupedBackground))
    }

    private func statCell(_ value: String, label: String, color: Color = .primary) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.system(.title3, design: .rounded, weight: .bold)).foregroundStyle(color)
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct DeviceFrameCard: View {
    let device: TimeLapseFrame.DeviceSnapshot

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(device.isOffline ? Color.red : Color.green)
                .frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 2) {
                Text(device.name)
                    .font(.caption.weight(.medium))
                    .lineLimit(1)
                if let room = device.room {
                    Text(room).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            Spacer(minLength: 0)
            if device.isBorderRouter {
                Text("BR").font(.caption2.weight(.semibold)).foregroundStyle(.blue)
            }
        }
        .padding(8)
        .cardBackground()
        .opacity(device.isOffline ? 0.6 : 1)
    }
}
