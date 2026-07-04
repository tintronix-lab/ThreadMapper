import SwiftUI
import CoreLocation
import Observation

struct SurveyMapView: View {
    let points: [SurveyPoint]
    @State private var selectedID: UUID?

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            Canvas { ctx, _ in
                guard let effective = effectiveBounds else { return }
                for point in points {
                    let x = CGFloat((point.coordinate.longitude - effective.minLng) / max(effective.spanLng, 1e-9)) * size.width
                    let y = CGFloat(1.0 - (point.coordinate.latitude - effective.minLat) / max(effective.spanLat, 1e-9)) * size.height
                    let rawRSSI = point.meanRSSI + 100
                    let boundedRSSI = max(0, min(rawRSSI, 50))
                    let r: CGFloat = 6 + min(CGFloat(boundedRSSI) * 0.35, 10)
                    ctx.fill(
                        Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)),
                        with: .color(color(for: point.meanRSSI))
                    )
                    ctx.stroke(
                        Path(ellipseIn: CGRect(x: x - r - 2, y: y - r - 2, width: (r + 2) * 2, height: (r + 2) * 2)),
                        with: .color(.black.opacity(0.12)),
                        style: .init(lineWidth: 1)
                    )
                    if selectedID == point.id {
                        ctx.stroke(
                            Path(ellipseIn: CGRect(x: x - r - 6, y: y - r - 6, width: (r + 6) * 2, height: (r + 6) * 2)),
                            with: .color(.accentColor),
                            style: .init(lineWidth: 2.5, lineCap: .round)
                        )
                    }
                }
            }
            .background(Color(white: 0.96).cornerRadius(10))
            .onTapGesture { location in
                guard let effective = effectiveBounds else { return }
                for point in points {
                    let x = CGFloat((point.coordinate.longitude - effective.minLng) / max(effective.spanLng, 1e-9)) * size.width
                    let y = CGFloat(1.0 - (point.coordinate.latitude - effective.minLat) / max(effective.spanLat, 1e-9)) * size.height
                    if abs(location.x - x) < 16 && abs(location.y - y) < 16 {
                        selectedID = point.id
                        return
                    }
                }
                if selectedID != nil { selectedID = nil }
            }
            .overlay(alignment: .topTrailing) {
                if let point = points.first(where: { $0.id == selectedID }) {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(point.timestamp, style: .date)
                        Text(String(format: "%.5f, %.5f", point.coordinate.latitude, point.coordinate.longitude))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text("RSSI \(String(format: "%.1f", point.meanRSSI)) dBm")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(10)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    .padding(10)
                }
            }
        }
        .navigationTitle("Survey Map")
    }

    private var effectiveBounds: (minLat: Double, maxLat: Double, minLng: Double, maxLng: Double, spanLat: Double, spanLng: Double)? {
        guard !points.isEmpty else { return nil }
        let lats = points.map { $0.coordinate.latitude }
        let lngs = points.map { $0.coordinate.longitude }
        let minLat = lats.min() ?? 0
        let maxLat = lats.max() ?? 0
        let minLng = lngs.min() ?? 0
        let maxLng = lngs.max() ?? 0
        return (minLat, maxLat, minLng, maxLng, max(maxLat - minLat, 1e-9), max(maxLng - minLng, 1e-9))
    }

    private func color(for rssi: Double) -> Color {
        if rssi < -80 { return .red }
        if rssi < -65 { return .orange }
        if rssi < -50 { return .yellow }
        return .green
    }
}
