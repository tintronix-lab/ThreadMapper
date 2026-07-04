import SwiftUI

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
                Image(systemName: roomIcon(room))
                    .font(.system(size: 44))
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
            }

            // Live signal preview while recording
            if isRecording {
                liveSignalRow
            }

            // Action buttons
            VStack(spacing: 12) {
                if isRecording {
                    Button {
                        stopRecording()
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
                if let rssi = device.rssi {
                    VStack(spacing: 2) {
                        Text("\(rssi)")
                            .font(.system(.caption, design: .monospaced).weight(.semibold))
                            .foregroundStyle(rssi > -65 ? Color.green : rssi > -80 ? Color.orange : Color.red)
                        Text(device.name)
                            .font(.system(size: 8))
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

    private var completionCard: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.12))
                    .frame(width: 100, height: 100)
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.green)
            }

            VStack(spacing: 8) {
                Text("Survey Complete!")
                    .font(.title.weight(.bold))
                Text("Surveyed \(completedRooms.count) of \(rooms.count) rooms. Results saved — open the Heatmap in the Survey tab to review coverage.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button {
                isPresented = false
            } label: {
                Label("Done", systemImage: "checkmark")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(24)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24))
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

    private func stopRecording() {
        sampleTask?.cancel(); sampleTask = nil
        tickTask?.cancel(); tickTask = nil
        if surveyVM.isRecording { surveyVM.toggleRecording() }
        isRecording = false
    }

    // MARK: - Helpers

    private func formatTime(_ seconds: Int) -> String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    private func roomIcon(_ room: String) -> String {
        let l = room.lowercased()
        if l.contains("kitchen")  { return "oven.fill" }
        if l.contains("bedroom")  { return "bed.double.fill" }
        if l.contains("living")   { return "sofa.fill" }
        if l.contains("bath")     { return "shower.fill" }
        if l.contains("garage")   { return "car.fill" }
        if l.contains("office")   { return "desktopcomputer" }
        if l.contains("hall")     { return "door.left.hand.open" }
        if l.contains("garden") || l.contains("outdoor") { return "leaf.fill" }
        return "house.fill"
    }
}
