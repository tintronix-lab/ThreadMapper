import SwiftUI
import UIKit

struct GuidedSurveyView: View {
    @Environment(SurveyViewModel.self) private var surveyVM
    @Environment(MeshViewModel.self) private var meshVM
    @Binding var isPresented: Bool

    let rooms: [String]

    @State private var currentIndex = 0
    @State private var completedRooms: Set<String> = []
    @State private var isRecording = false
    @State private var sampleTask: Task<Void, Never>?
    @State private var elapsedSeconds = 0
    @State private var tickTask: Task<Void, Never>?
    @State private var hapticEnabled = false
    @State private var hapticTask: Task<Void, Never>?

    private var isDone: Bool { currentIndex >= rooms.count }
    private var currentRoom: String? { isDone ? nil : rooms[currentIndex] }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                progressHeader
                Spacer()
                if let room = currentRoom {
                    roomCard(room)
                } else {
                    completionCard
                }
                Spacer()
            }
            .padding(.horizontal)
            .navigationTitle("Guided Survey")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        stopRecording()
                        isPresented = false
                    }
                }
                if isRecording {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            hapticEnabled.toggle()
                            if hapticEnabled { startHapticPulse() } else { hapticTask?.cancel() }
                        } label: {
                            Image(systemName: hapticEnabled ? "waveform.circle.fill" : "waveform.circle")
                                .symbolEffect(.pulse, isActive: hapticEnabled)
                        }
                        .tint(hapticEnabled ? .accentColor : .secondary)
                    }
                }
            }
        }
        .onDisappear { stopRecording() }
    }

    // MARK: - Progress header

    private var progressHeader: some View {
        VStack(spacing: 8) {
            ProgressView(value: Double(completedRooms.count), total: Double(max(rooms.count, 1)))
                .tint(.accentColor)
                .animation(.easeOut, value: completedRooms.count)

            HStack {
                Text("\(completedRooms.count) of \(rooms.count) rooms")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                if isRecording {
                    HStack(spacing: 4) {
                        Circle().fill(.red).frame(width: 6, height: 6)
                        Text(formatTime(elapsedSeconds))
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.red)
                    }
                }
            }

            // Room chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(Array(rooms.enumerated()), id: \.offset) { i, room in
                        roomChip(room, index: i)
                    }
                }
                .padding(.horizontal, 2)
            }
        }
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private func roomChip(_ room: String, index: Int) -> some View {
        let isDone = completedRooms.contains(room)
        let isCurrent = index == currentIndex

        HStack(spacing: 4) {
            if isDone {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .imageScale(.small)
            }
            Text(room)
                .lineLimit(1)
        }
        .font(.caption)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            isCurrent ? Color.accentColor.opacity(0.15) :
            isDone    ? Color.green.opacity(0.10)       : Color.secondary.opacity(0.08),
            in: Capsule()
        )
        .overlay(
            isCurrent ? Capsule().stroke(Color.accentColor, lineWidth: 1.5) : Capsule().stroke(Color.clear, lineWidth: 0)
        )
        .foregroundStyle(isCurrent ? Color.accentColor : isDone ? Color.green : Color.secondary)
    }

    // MARK: - Room card

    @ViewBuilder
    private func roomCard(_ room: String) -> some View {
        VStack(spacing: 24) {
            // Icon
            ZStack {
                Circle()
                    .fill(isRecording ? Color.red.opacity(0.1) : Color.accentColor.opacity(0.1))
                    .frame(width: 100, height: 100)
                Image(systemName: TMStyle.roomIcon(room))
                    .font(.largeTitle)
                    .foregroundStyle(isRecording ? .red : .accentColor)
                    .symbolEffect(.pulse, isActive: isRecording)
            }

            VStack(spacing: 8) {
                Text(room)
                    .font(.title.weight(.bold))
                Text(isRecording
                     ? "Walk around \(room) while recording captures signal data."
                     : "Stand in the center of \(room), then tap Start.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                if !isRecording {
                    Label("Tap the waveform button while recording to feel signal strength via haptics.", systemImage: "waveform.circle")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                }
            }

            // Live signal preview while recording
            if isRecording {
                liveSignalRow
            }

            // Action buttons
            VStack(spacing: 12) {
                if isRecording {
                    Button {
                        stopRecording(room: room)
                        completedRooms.insert(room)
                        currentIndex += 1
                    } label: {
                        Label("Done with \(room)", systemImage: "checkmark.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    .controlSize(.large)
                } else {
                    Button {
                        startRecording()
                    } label: {
                        Label("Start Recording", systemImage: "record.circle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }

                Button {
                    stopRecording()
                    currentIndex += 1
                } label: {
                    Text("Skip \(room)")
                        .font(.subheadline)
                }
                .foregroundStyle(.secondary)
                .disabled(isRecording)
            }
        }
        .padding(24)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24))
    }

    private var liveSignalRow: some View {
        HStack(spacing: 12) {
            ForEach(meshVM.devices.prefix(4)) { device in
                if device.rssi != nil {
                    let rssi = device.rssi!
                    VStack(spacing: 2) {
                        Text(rssi.rssiQualityLabel)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(rssi.rssiColor)
                        Text(device.name)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(10)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Completion card

    @ViewBuilder
    private var completionCard: some View {
        let stats = surveyVM.roomStats().filter { completedRooms.contains($0.room) }
        let best  = stats.max(by: { $0.avgRSSI < $1.avgRSSI })
        let worst = stats.min(by: { $0.avgRSSI < $1.avgRSSI })
        let weakNames = surveyVM.weakDeviceNames(for: completedRooms)

        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.12))
                    .frame(width: 100, height: 100)
                Image(systemName: "checkmark.circle.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.green)
            }

            VStack(spacing: 6) {
                Text("Survey Complete")
                    .font(.title.weight(.bold))
                Text("\(completedRooms.count) of \(rooms.count) ^[room](inflect: true) surveyed")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if !stats.isEmpty {
                VStack(spacing: 10) {
                    if let best = best {
                        resultRow(
                            label: "Best coverage",
                            room: best.room,
                            rssi: best.avgRSSI,
                            icon: "checkmark.seal.fill",
                            tint: .green
                        )
                    }
                    if let worst = worst, worst.room != best?.room {
                        resultRow(
                            label: worst.avgRSSI < -75 ? "Needs a router nearby" : "Weakest room",
                            room: worst.room,
                            rssi: worst.avgRSSI,
                            icon: worst.avgRSSI < -75 ? "exclamationmark.triangle.fill" : "wifi.exclamationmark",
                            tint: worst.avgRSSI < -75 ? .orange : .yellow
                        )
                    }
                    if !weakNames.isEmpty {
                        HStack(spacing: 10) {
                            Image(systemName: "wifi.slash")
                                .foregroundStyle(.red)
                                .frame(width: 20)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("^[\(weakNames.count) weak device](inflect: true) detected")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.primary)
                                Text(weakNames.joined(separator: ", "))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.red.opacity(0.07), in: RoundedRectangle(cornerRadius: 10))
                    }
                }
            }

            Button { isPresented = false } label: {
                Label("Done", systemImage: "checkmark")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(24)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24))
    }

    @ViewBuilder
    private func resultRow(label: String, room: String, rssi: Double, icon: String, tint: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(tint)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                HStack(spacing: 6) {
                    Image(systemName: TMStyle.roomIcon(room))
                        .imageScale(.small)
                    Text(room)
                        .font(.subheadline.weight(.semibold))
                }
            }
            Spacer()
            Text(Int(rssi.rounded()).rssiQualityLabel)
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint)
        }
        .padding(10)
        .background(tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Sampling

    private func startRecording() {
        guard !surveyVM.isRecording else { return }
        surveyVM.toggleRecording()
        isRecording = true
        elapsedSeconds = 0

        tickTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { break }
                await MainActor.run { elapsedSeconds += 1 }
            }
        }

        sampleTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(3))
                guard !Task.isCancelled else { break }
                await MainActor.run {
                    surveyVM.recordCurrentDevices(meshVM.devices)
                }
            }
        }
    }

    private func stopRecording(room: String? = nil) {
        sampleTask?.cancel(); sampleTask = nil
        tickTask?.cancel(); tickTask = nil
        hapticTask?.cancel(); hapticTask = nil
        hapticEnabled = false
        // Tag the saved session with the surveyed room — the reliable indoor
        // position signal (GPS is not, at room scale).
        if surveyVM.isRecording { surveyVM.toggleRecording(room: room) }
        isRecording = false
        // Unlock survey achievements based on rooms completed so far + this one
        let totalCompleted = completedRooms.count + (room != nil ? 1 : 0)
        if totalCompleted >= 1 { AchievementStore.shared.unlock("firstSurvey") }
        if totalCompleted >= 3 { AchievementStore.shared.unlock("surveyThreeRooms") }
    }

    // MARK: - Haptic Geiger Mode

    private func startHapticPulse() {
        hapticTask?.cancel()
        hapticTask = Task {
            while !Task.isCancelled {
                let avgRSSI = meshVM.devices.compactMap(\.rssi).reduce(0, +) / max(1, meshVM.devices.compactMap(\.rssi).count)
                let (interval, style): (Double, UIImpactFeedbackGenerator.FeedbackStyle) = {
                    switch avgRSSI {
                    case ..<(-85): return (3.0, .light)
                    case ..<(-75): return (1.8, .light)
                    case ..<(-65): return (1.0, .medium)
                    case ..<(-55): return (0.5, .medium)
                    default:       return (0.3, .heavy)
                    }
                }()
                await MainActor.run {
                    UIImpactFeedbackGenerator(style: style).impactOccurred()
                }
                try? await Task.sleep(for: .seconds(interval))
            }
        }
    }

    // MARK: - Helpers

    private func formatTime(_ seconds: Int) -> String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}
