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

// MARK: - Heatmap Canvas

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
