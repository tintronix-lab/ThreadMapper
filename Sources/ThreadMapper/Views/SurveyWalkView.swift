import SwiftUI
import CoreLocation
import Observation

struct SurveyWalkView: View {
    @Environment(SurveyViewModel.self) private var viewModel
    @State private var showHeatmap = false
    @State private var radiusMeters: Double = 35
    @State private var resolutionMeters: Double = 12
    @State private var heatmapPoints: [SurveyHeatmapPresenter.Cell] = []

    var body: some View {
        NavigationStack {
            Form {
                Section("Library") {
                    NavigationLink("Saved Surveys") {
                        SavedSurveyList()
                    }
                }

                Section {
                    Button {
                        viewModel.toggleRecording()
                        if !viewModel.isRecording {
                            viewModel.loadRecentSamplePoints { points in
                                if showHeatmap {
                                    heatmapPoints = SurveyHeatmapPresenter.present(
                                        points: points,
                                        radiusMeters: radiusMeters,
                                        resolutionMeters: resolutionMeters
                                    )
                                }
                            }
                        }
                    } label: {
                        Label(viewModel.isRecording ? "Stop Survey" : "Start Survey",
                              systemImage: viewModel.isRecording ? "stop.circle.fill" : "record.circle")
                    }
                    .tint(viewModel.isRecording ? .red : .green)

                    Button("Reset Survey") {
                        viewModel.resetSession()
                        heatmapPoints.removeAll()
                    }
                    .disabled(viewModel.isRecording)
                }

                Section("Current Reading") {
                    locationGuidance
                    readingAndQuality
                    sessionStats
                }

                Section("Heatmap") {
                    Toggle("Show Heatmap", isOn: $showHeatmap)
                    if showHeatmap {
                        Text("\(heatmapPoints.count) cell\(heatmapPoints.count == 1 ? "" : "s") loaded")
                        Slider(value: $radiusMeters, in: 10...80, step: 5) {
                            Text("Radius: \(Int(radiusMeters))m")
                        }
                        .onChange(of: radiusMeters) { refreshHeatmap() }
                        Slider(value: $resolutionMeters, in: 6...25, step: 1) {
                            Text("Resolution: \(Int(resolutionMeters))m")
                        }
                        .onChange(of: resolutionMeters) { refreshHeatmap() }

                        heatmapVisualization
                        weakSpotSummary(from: heatmapPoints)
                    }

                    exportActions
                }

                Section("Weak Links") {
                    weakLinksContent
                }
            }
            .navigationTitle("Survey Walk")
            .onAppear { refreshHeatmap() }
        }
    }

    @ViewBuilder
    private var locationGuidance: some View {
        HStack(spacing: 10) {
            Image(systemName: "location.north.fill")
            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.locationStatusLabel)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("Best results while walking near Thread devices.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var readingAndQuality: some View {
        Group {
            if let rssi = viewModel.currentRSSI {
                let quality = viewModel.signalQuality(for: rssi)
                HStack {
                    Text("RSSI: \(Int(rssi)) dBm")
                        .font(.system(.body, design: .monospaced))
                    Spacer()
                    Text(quality.label)
                        .font(.caption2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(quality.color.opacity(0.2))
                        .foregroundStyle(quality.color)
                        .clipShape(Capsule())
                }
            } else {
                Text("No readings yet").foregroundStyle(.secondary)
            }
        }
    }

    private var sessionStats: some View {
        HStack(spacing: 12) {
            Label("\(viewModel.sessionSampleCount) samples", systemImage: "waveform.path")
            Label("\(viewModel.sessionWeakCount) weak", systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(viewModel.sessionWeakCount > 0 ? .orange : .secondary)
            Spacer()
            Text(viewModel.locationStatusLabel)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
    }

    @ViewBuilder
    private var exportActions: some View {
        if let surveyURL = viewModel.exportCSVURL() {
            ShareLink("Export Survey CSV", item: surveyURL)
        }

        if let deviceURL = viewModel.exportURLForCurrentSessionPerDevice() {
            ShareLink("Export Device CSV", item: deviceURL)
        }

        if viewModel.savedPointCount > 0 {
            Text("Saved surveys: \(viewModel.savedPointCount)")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var weakLinksContent: some View {
        let ordered = viewModel.weakDevices.sorted { $0.name < $1.name }
        if ordered.isEmpty {
            LabeledContent("Threshold", value: "RSSI < -80 dBm")
            Text("No weak links recorded in this session.")
                .foregroundStyle(.secondary)
        } else {
            ForEach(ordered) { device in
                let q = viewModel.signalQuality(for: device.rssi)
                HStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(device.name)
                            .font(.body)
                        Text(q.label)
                            .font(.caption2)
                            .foregroundStyle(q.color)
                    }
                    Spacer()
                    Text("\(device.rssi) dBm")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private func weakSpotSummary(from cells: [SurveyHeatmapPresenter.Cell]) -> some View {
        let spots = SurveyHeatmapPresenter.weakSpots(from: cells)
        if spots.isEmpty {
            Text("No weak coverage detected.")
                .foregroundStyle(.secondary)
        } else {
            VStack(alignment: .leading, spacing: 6) {
                Text("Weak spots:")
                ForEach(Array(spots.enumerated()), id: \.offset) { _, cell in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(String(format: "Coverage %.2f • %d weak device(s)", cell.score, cell.weakDeviceCount))
                                .font(.caption)
                                .foregroundStyle(.orange)
                            Text(String(format: "%.5f, %.5f", cell.coordinate.latitude, cell.coordinate.longitude))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    private func refreshHeatmap() {
        if showHeatmap {
            viewModel.loadRecentSamplePoints { points in
                heatmapPoints = SurveyHeatmapPresenter.present(
                    points: points,
                    radiusMeters: radiusMeters,
                    resolutionMeters: resolutionMeters
                )
            }
        }
    }

    @ViewBuilder
    private var heatmapVisualization: some View {
        if heatmapPoints.isEmpty {
            Text("No heatmap data yet")
                .foregroundStyle(.secondary)
        } else {
            HeatmapCanvas(cells: heatmapPoints, focus: viewModel.lastSavedFocus)
                .frame(height: 160)
                .padding(.vertical, 4)
        }
    }
}

struct HeatmapCanvas: View {
    let cells: [SurveyHeatmapPresenter.Cell]
    var focus: CLLocationCoordinate2D?

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            Canvas { ctx, canvasSize in
                guard let effectiveBounds = effectiveBounds else { return }
                for cell in cells {
                    let x = CGFloat((cell.coordinate.longitude - effectiveBounds.minLng) / max(effectiveBounds.spanLng, 1e-9)) * size.width
                    let y = CGFloat(1.0 - (cell.coordinate.latitude - effectiveBounds.minLat) / max(effectiveBounds.spanLat, 1e-9)) * size.height
                    let rect = CGRect(x: x - 4, y: y - 4, width: 8, height: 8)
                    ctx.fill(
                        Path(roundedRect: rect, cornerRadius: 3),
                        with: .color(color(for: cell.score))
                    )
                }
            }
            .background(Color(white: 0.96).cornerRadius(10))
        }
        .frame(height: 160)
    }

    private var effectiveBounds: (minLat: Double, maxLat: Double, minLng: Double, maxLng: Double, spanLat: Double, spanLng: Double)? {
        guard !cells.isEmpty else { return nil }
        var lats = cells.map { $0.coordinate.latitude }
        var lngs = cells.map { $0.coordinate.longitude }
        if let focus {
            lats.append(focus.latitude)
            lngs.append(focus.longitude)
        }
        let minLat = lats.min() ?? 0
        let maxLat = lats.max() ?? 0
        let minLng = lngs.min() ?? 0
        let maxLng = lngs.max() ?? 0
        return (minLat, maxLat, minLng, maxLng, max(maxLat - minLat, 1e-9), max(maxLng - minLng, 1e-9))
    }

    private func color(for score: Double) -> Color {
        if score < 0.35 { return .red }
        if score < 0.55 { return .orange }
        if score < 0.75 { return .yellow }
        return .green
    }
}

