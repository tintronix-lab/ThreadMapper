import SwiftUI
import CoreLocation

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
            .navigationTitle("Survey Walk")
            .navigationBarTitleDisplayMode(.inline)
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
        Section {
            Button {
                showGuidedSurvey = true
            } label: {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(Color.accentColor.opacity(0.1))
                            .frame(width: 44, height: 44)
                        Image(systemName: "house.and.flag.fill")
                            .font(.title3)
                            .foregroundStyle(Color.accentColor)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Survey My Home")
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text("Room-by-room guided walk with instant results")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(.vertical, 4)
            }
            .buttonStyle(.plain)
            .disabled(meshVM.rooms.isEmpty)
        } header: {
            HStack {
                Text("Survey")
                Spacer()
                NavigationLink("Saved (\(viewModel.savedPointCount))") {
                    SavedSurveyList()
                }
                .font(.caption)
            }
        } footer: {
            if meshVM.rooms.isEmpty {
                Text("No rooms found — scan for devices first.")
            }
        }
    }

    @ViewBuilder
    private var roomCoverageSection: some View {
        let stats = viewModel.roomStats()
        if !stats.isEmpty {
            Section {
                ForEach(stats, id: \.room) { stat in
                    roomCoverageBar(room: stat.room, avgRSSI: stat.avgRSSI, sampleCount: stat.sampleCount)
                }
            } header: {
                HStack {
                    Text("Room Coverage")
                    Spacer()
                    Text("\(stats.count) room\(stats.count == 1 ? "" : "s")")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
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
                    Text("\(meshVM.devices.count) device\(meshVM.devices.count == 1 ? "" : "s")")
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
        } header: {
            Text("Free Walk")
        } footer: {
            Text("Records GPS-tagged samples as you walk. Use Guided Survey above for room-based results.")
        }
    }

    @ViewBuilder
    private var currentReadingSection: some View {
        Section {
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
                                    .font(.system(size: 9))
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
        } header: {
            HStack {
                Text("Live Signal")
                Spacer()
                Text("Via HomeKit latency")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    @ViewBuilder
    private var heatmapSection: some View {
        Section("Heatmap") {
            Toggle("Show Heatmap", isOn: $showHeatmap)
                .onChange(of: showHeatmap) { _, isOn in
                    if isOn { refreshHeatmap() }
                }

            if showHeatmap {
                if heatmapPoints.isEmpty {
                    Text("No survey data yet")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    HeatmapCanvas(cells: heatmapPoints, focus: viewModel.lastSavedFocus)
                        .frame(height: 140)
                        .padding(.vertical, 2)

                    Text("\(heatmapPoints.count) cell\(heatmapPoints.count == 1 ? "" : "s")")
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
    }

    @ViewBuilder
    private var weakLinksSection: some View {
        let ordered = viewModel.weakDevices.sorted { $0.name < $1.name }
        Section("Weak Links") {
            if ordered.isEmpty {
                Text("None — threshold RSSI < −80 dBm")
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
                Text("\(spots.count) weak spot\(spots.count == 1 ? "" : "s") detected — consider adding a Thread router")
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

// MARK: - HeatmapCanvas

struct HeatmapCanvas: View {
    let cells: [SurveyHeatmapPresenter.Cell]
    var focus: CLLocationCoordinate2D?

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            Canvas { ctx, _ in
                guard let b = bounds else { return }
                for cell in cells {
                    let x = CGFloat((cell.coordinate.longitude - b.minLng) / b.spanLng) * size.width
                    let y = CGFloat(1 - (cell.coordinate.latitude - b.minLat) / b.spanLat) * size.height
                    ctx.fill(
                        Path(roundedRect: CGRect(x: x - 4, y: y - 4, width: 8, height: 8), cornerRadius: 2),
                        with: .color(heatColor(for: cell.score))
                    )
                }
            }
            .background(Color(UIColor.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8))
        }
    }

    private var bounds: (minLat: Double, minLng: Double, spanLat: Double, spanLng: Double)? {
        guard !cells.isEmpty else { return nil }
        var lats = cells.map { $0.coordinate.latitude }
        var lngs = cells.map { $0.coordinate.longitude }
        if let f = focus { lats.append(f.latitude); lngs.append(f.longitude) }
        let minLat = lats.min()!, maxLat = lats.max()!
        let minLng = lngs.min()!, maxLng = lngs.max()!
        return (minLat, minLng, max(maxLat - minLat, 1e-9), max(maxLng - minLng, 1e-9))
    }

    private func heatColor(for score: Double) -> Color {
        if score < 0.35 { return .red }
        if score < 0.55 { return .orange }
        if score < 0.75 { return .yellow }
        return .green
    }
}
