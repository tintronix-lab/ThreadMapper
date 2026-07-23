import CoreLocation
import SwiftUI

struct SurveyWalkView: View {
    @Environment(SurveyViewModel.self) private var viewModel
    @Environment(MeshViewModel.self) private var meshVM

    @State private var showHeatmap = false
    @State private var radiusMeters: Double = 35
    @State private var resolutionMeters: Double = 12
    @State private var heatmapPoints: [SurveyHeatmapPresenter.Cell] = []
    @State private var sampleTask: Task<Void, Never>?
    @State private var lastUpdateTime: Date?
    @State private var showGuidedSurvey = false
    // Generated on refresh, not in body — generating in body wrote a temp file on every render.
    @State private var exportURL: URL?

    @AppStorage("survey.roomCoverage.expanded") private var roomCoverageExpanded = true
    @AppStorage("survey.liveSignal.expanded")   private var liveSignalExpanded = true
    @AppStorage("survey.heatmap.expanded")      private var heatmapExpanded = true
    @AppStorage("survey.freeWalk.expanded")     private var freeWalkExpanded = true
    @AppStorage("survey.weakLinks.expanded")    private var weakLinksExpanded = true

    var body: some View {
        NavigationStack {
            Form {
                guidedSurveySection
                roomCoverageSection
                currentReadingSection
                heatmapSection
                freeWalkSection
                weakLinksSection
            }
            .navigationTitle("Survey")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                refreshHeatmap()
                startSampling()
            }
            .onDisappear { stopSampling() }
            .sheet(isPresented: $showGuidedSurvey) {
                GuidedSurveyView(isPresented: $showGuidedSurvey, rooms: meshVM.rooms)
                    .onDisappear { refreshHeatmap() }
            }
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var guidedSurveySection: some View {
        SurveyGuidedSection(showGuidedSurvey: $showGuidedSurvey)
    }

    @ViewBuilder
    private var roomCoverageSection: some View {
        let stats = viewModel.roomStats()
        if !stats.isEmpty {
            Section {
                if roomCoverageExpanded {
                    ForEach(stats, id: \.room) { stat in
                        roomCoverageBar(room: stat.room, avgRSSI: stat.avgRSSI, sampleCount: stat.sampleCount)
                    }
                }
            } header: {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { roomCoverageExpanded.toggle() }
                } label: {
                    HStack(spacing: 6) {
                        Text("Room Coverage")
                        Spacer()
                        if !roomCoverageExpanded {
                            Text("^[\(stats.count) room](inflect: true)")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        Image(systemName: roomCoverageExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .textCase(nil)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private func roomCoverageBar(room: String, avgRSSI: Double, sampleCount: Int) -> some View {
        let rssiInt = Int(avgRSSI.rounded())
        let color = rssiInt.rssiColor
        let quality = rssiInt.rssiQualityLabel
        let fraction = max(0.0, min(1.0, (avgRSSI + 100.0) / 50.0))
        VStack(spacing: 6) {
            HStack {
                Image(systemName: TMStyle.roomIcon(room))
                    .foregroundStyle(color)
                    .imageScale(.small)
                    .frame(width: 18)
                Text(room)
                    .font(.subheadline)
                Spacer()
                Text(quality)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(color)
                Text("· \(sampleCount) samples")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color.opacity(0.12))
                        .frame(height: 5)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color)
                        .frame(width: geo.size.width * fraction, height: 5)
                }
            }
            .frame(height: 5)
            .animation(.easeOut(duration: 0.5), value: fraction)
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var freeWalkSection: some View {
        Section {
            if freeWalkExpanded {
                Button {
                    viewModel.toggleRecording()
                    if !viewModel.isRecording { refreshHeatmap() }
                } label: {
                    Label(
                        viewModel.isRecording ? "Stop Walk" : "Start Free Walk",
                        systemImage: viewModel.isRecording ? "stop.circle.fill" : "figure.walk"
                    )
                    .foregroundStyle(viewModel.isRecording ? .red : .secondary)
                }

                if viewModel.isRecording {
                    HStack(spacing: 6) {
                        Circle().fill(.red).frame(width: 7, height: 7)
                        Text("Recording — \(viewModel.sessionSampleCount) samples")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("^[\(meshVM.devices.count) device](inflect: true)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Button("Reset") {
                    viewModel.resetSession()
                    heatmapPoints.removeAll()
                }
                .foregroundStyle(.secondary)
                .disabled(viewModel.isRecording)
            }
        } header: {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { freeWalkExpanded.toggle() }
            } label: {
                HStack(spacing: 6) {
                    Text("Free Walk")
                    Spacer()
                    Image(systemName: freeWalkExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .textCase(nil)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        } footer: {
            if freeWalkExpanded {
                Text("Records GPS-tagged samples as you walk. Use Guided Survey above for room-based results.")
            }
        }
    }

    @ViewBuilder
    private var currentReadingSection: some View {
        Section {
            if liveSignalExpanded {
                if meshVM.devices.isEmpty {
                    Label("No Thread devices — connect via HomeKit first", systemImage: "antenna.radiowaves.left.and.right.slash")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(meshVM.devices) { device in
                        let rssi = device.rssi
                        let q = viewModel.signalQuality(for: rssi ?? -65)
                        HStack(spacing: 10) {
                            Image(systemName: rssi == nil ? "wifi.slash" : "wifi")
                                .foregroundStyle(rssi == nil ? Color.secondary : q.color)
                                .imageScale(.small)
                                .frame(width: 18)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(device.name)
                                    .font(.caption.weight(.medium))
                                    .lineLimit(1)
                                if let room = device.room {
                                    Text(room)
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                            Spacer()
                            if device.rssi != nil {
                                VStack(alignment: .trailing, spacing: 1) {
                                    Text(q.label)
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(q.color)
                                    Text("response quality")
                                        .font(.caption2)
                                        .foregroundStyle(q.color.opacity(0.7))
                                }
                            } else {
                                Text("Measuring…")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 1)
                    }

                    HStack(spacing: 6) {
                        Image(systemName: "location.fill")
                            .foregroundStyle(.blue)
                            .imageScale(.small)
                        Text(viewModel.locationStatusLabel)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Spacer()
                        if let t = lastUpdateTime {
                            Text("Updated \(t, style: .relative) ago")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }

                if viewModel.isRecording || viewModel.sessionSampleCount > 0 {
                    HStack(spacing: 16) {
                        Label("\(viewModel.sessionSampleCount) samples", systemImage: "waveform.path")
                        Label("\(viewModel.sessionWeakCount) weak", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(viewModel.sessionWeakCount > 0 ? .orange : .secondary)
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
            }
        } header: {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { liveSignalExpanded.toggle() }
            } label: {
                HStack(spacing: 6) {
                    Text("Live Signal")
                    Spacer()
                    if !liveSignalExpanded {
                        Text("^[\(meshVM.devices.count) device](inflect: true)")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    Image(systemName: liveSignalExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .textCase(nil)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var heatmapSection: some View {
        let roomStats = viewModel.roomStats()
        Section {
            if heatmapExpanded {
                // Room signal grid — always useful after a guided survey, no GPS needed
                if !roomStats.isEmpty {
                    RoomSignalGrid(stats: roomStats)
                        .padding(.vertical, 4)
                }

                Toggle("GPS Signal Map", isOn: $showHeatmap)
                    .onChange(of: showHeatmap) { _, isOn in
                        if isOn { refreshHeatmap() }
                    }

                if showHeatmap {
                    if heatmapPoints.isEmpty {
                        Label(
                            "Walk with the app open outdoors to build a GPS coverage map",
                            systemImage: "figure.walk.circle"
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 4)
                    } else {
                        HeatmapCanvas(
                            cells: heatmapPoints,
                            focus: viewModel.lastSavedFocus,
                            resolutionMeters: resolutionMeters
                        )
                        .frame(height: 220)
                        .padding(.vertical, 2)

                        Text("^[\(heatmapPoints.count) cell](inflect: true)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)

                        weakSpotSummary(from: heatmapPoints)
                    }

                    VStack(spacing: 2) {
                        HStack {
                            Text("Radius")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(Int(radiusMeters)) m")
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: $radiusMeters, in: 10...80, step: 5)
                            .onChange(of: radiusMeters) { refreshHeatmap() }
                    }

                    VStack(spacing: 2) {
                        HStack {
                            Text("Resolution")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(Int(resolutionMeters)) m")
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: $resolutionMeters, in: 6...25, step: 1)
                            .onChange(of: resolutionMeters) { refreshHeatmap() }
                    }

                    exportActions
                }
            }
        } header: {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { heatmapExpanded.toggle() }
            } label: {
                HStack(spacing: 6) {
                    Text("Coverage Map")
                    Spacer()
                    Image(systemName: heatmapExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .textCase(nil)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var weakLinksSection: some View {
        let ordered = viewModel.weakDevices.sorted { $0.name < $1.name }
        Section {
            if weakLinksExpanded {
                if ordered.isEmpty {
                    Text("None — threshold response quality < −80")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(ordered) { device in
                        let q = viewModel.signalQuality(for: device.rssi)
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                                .imageScale(.small)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(device.name)
                                    .font(.subheadline)
                                    .lineLimit(1)
                                Text("\(q.label) signal")
                                    .font(.caption2)
                                    .foregroundStyle(q.color)
                            }
                        }
                    }
                }
            }
        } header: {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { weakLinksExpanded.toggle() }
            } label: {
                HStack(spacing: 6) {
                    Text("Weak Links")
                    Spacer()
                    if !weakLinksExpanded && !ordered.isEmpty {
                        Text("\(ordered.count)")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.orange)
                    }
                    Image(systemName: weakLinksExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .textCase(nil)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Sub-views

    @ViewBuilder
    private var exportActions: some View {
        if let url = exportURL {
            ShareLink("Export CSV", item: url)
                .font(.caption)
        }
    }

    @ViewBuilder
    private func weakSpotSummary(from cells: [SurveyHeatmapPresenter.Cell]) -> some View {
        let spots = SurveyHeatmapPresenter.weakSpots(from: cells)
        if !spots.isEmpty {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .imageScale(.small)
                Text("^[\(spots.count) weak spot](inflect: true) detected — consider adding a Thread router")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Sampling

    private func startSampling() {
        sampleTask?.cancel()
        sampleTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(5))
                guard !Task.isCancelled else { break }
                await MainActor.run {
                    lastUpdateTime = Date()
                    if viewModel.isRecording {
                        viewModel.recordCurrentDevices(meshVM.devices)
                    }
                }
            }
        }
    }

    private func stopSampling() {
        sampleTask?.cancel()
        sampleTask = nil
    }

    private func refreshHeatmap() {
        exportURL = viewModel.exportCSVURL()
        guard showHeatmap else { return }
        viewModel.loadRecentSamplePoints { points in
            heatmapPoints = SurveyHeatmapPresenter.present(
                points: points,
                radiusMeters: radiusMeters,
                resolutionMeters: resolutionMeters
            )
        }
    }
}

