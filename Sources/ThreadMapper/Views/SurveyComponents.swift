import SwiftUI
import CoreLocation

// MARK: - Guided Survey Entry Section

struct SurveyGuidedSection: View {
    @Binding var showGuidedSurvey: Bool
    @Environment(SurveyViewModel.self) private var viewModel
    @Environment(MeshViewModel.self) private var meshVM

    var body: some View {
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
}

// MARK: - Room Signal Grid

struct RoomSignalGrid: View {
    let stats: [(room: String, avgRSSI: Double, sampleCount: Int)]
    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(stats, id: \.room) { stat in
                RoomSignalCard(stat: stat)
            }
        }
    }
}

private struct RoomSignalCard: View {
    let stat: (room: String, avgRSSI: Double, sampleCount: Int)

    var body: some View {
        let rssi = Int(stat.avgRSSI.rounded())
        let color = rssi.rssiColor
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top) {
                Image(systemName: TMStyle.roomIcon(stat.room))
                    .font(.caption)
                    .foregroundStyle(color)
                Spacer()
                Text(grade(rssi))
                    .font(.title2.weight(.bold))
                    .foregroundStyle(color)
            }
            Text(stat.room)
                .font(.caption.weight(.medium))
                .lineLimit(1)
            HStack {
                Text(String(localized: rssi.rssiQualityLabel))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(color)
                Spacer()
                Text("^[\(stat.sampleCount) sample](inflect: true)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(10)
        .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
    }

    private func grade(_ rssi: Int) -> String {
        if rssi > SignalThresholds.excellent { return "A" }
        if rssi > SignalThresholds.good { return "B" }
        if rssi > SignalThresholds.weak { return "C" }
        return "D"
    }
}

// MARK: - Heatmap Canvas

struct HeatmapCanvas: View {
    let cells: [SurveyHeatmapPresenter.Cell]
    var focus: CLLocationCoordinate2D?
    /// Matches the resolution slider in SurveyWalkView so cell circles are
    /// sized to fill their grid square rather than being tiny fixed dots.
    var resolutionMeters: Double = 12.0

    var body: some View {
        VStack(spacing: 6) {
            GeometryReader { geo in
                let size = geo.size
                Canvas { ctx, _ in
                    guard let b = bounds else { return }
                    // Pixel size of one grid cell based on canvas dimensions + resolution
                    let lngPxPerDeg = size.width / b.spanLng
                    let latPxPerDeg = size.height / b.spanLat
                    let cellPxW = CGFloat(resolutionMeters / 111_320.0 * lngPxPerDeg)
                    let cellPxH = CGFloat(resolutionMeters / 110_540.0 * latPxPerDeg)
                    // Radius slightly smaller than cell half-width so adjacent circles
                    // overlap softly without producing a solid block of color.
                    let cellR = max(6, min(cellPxW, cellPxH) * 0.65)

                    // Bad cells first so good cells visually overlay them
                    for cell in cells {
                        let x = CGFloat((cell.coordinate.longitude - b.minLng) / b.spanLng) * size.width
                        let y = CGFloat(1 - (cell.coordinate.latitude - b.minLat) / b.spanLat) * size.height
                        ctx.fill(
                            Path(ellipseIn: CGRect(x: x - cellR, y: y - cellR, width: cellR * 2, height: cellR * 2)),
                            with: .color(heatColor(for: cell.score).opacity(0.78))
                        )
                    }

                    // Focus marker — white dot with blue ring at the last sampled location
                    if let f = focus {
                        let fx = CGFloat((f.longitude - b.minLng) / b.spanLng) * size.width
                        let fy = CGFloat(1 - (f.latitude - b.minLat) / b.spanLat) * size.height
                        ctx.fill(
                            Path(ellipseIn: CGRect(x: fx - 5, y: fy - 5, width: 10, height: 10)),
                            with: .color(.white)
                        )
                        ctx.stroke(
                            Path(ellipseIn: CGRect(x: fx - 6, y: fy - 6, width: 12, height: 12)),
                            with: .color(.blue.opacity(0.9)),
                            lineWidth: 2
                        )
                    }
                }
                .background(Color(UIColor.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8))
                .accessibilityLabel(Text("Survey coverage heatmap"))
                .accessibilityValue(Text("^[\(cells.count) surveyed point](inflect: true)"))
            }

            // Color legend
            HStack(spacing: 6) {
                Text("Poor")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                LinearGradient(colors: [.red, .orange, .yellow, .green],
                               startPoint: .leading, endPoint: .trailing)
                    .frame(height: 5)
                    .clipShape(Capsule())
                Text("Good")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var bounds: (minLat: Double, minLng: Double, spanLat: Double, spanLng: Double)? {
        guard !cells.isEmpty else { return nil }
        var lats = cells.map { $0.coordinate.latitude }
        var lngs = cells.map { $0.coordinate.longitude }
        if let f = focus { lats.append(f.latitude); lngs.append(f.longitude) }
        guard let minLat = lats.min(), let maxLat = lats.max(),
              let minLng = lngs.min(), let maxLng = lngs.max() else { return nil }
        return (minLat, minLng, max(maxLat - minLat, 1e-9), max(maxLng - minLng, 1e-9))
    }

    private func heatColor(for score: Double) -> Color {
        if score < 0.35 { return .red }
        if score < 0.55 { return .orange }
        if score < 0.75 { return .yellow }
        return .green
    }
}
