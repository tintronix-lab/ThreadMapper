import SwiftUI
import MapKit
import CoreLocation

struct SurveyMapView: View {
    let points: [SurveyPoint]
    var highlighted: UUID? = nil

    @State private var selectedID: UUID?
    @State private var cameraPosition: MapCameraPosition

    init(points: [SurveyPoint], highlighted: UUID? = nil) {
        self.points = points
        self.highlighted = highlighted
        self._selectedID = State(initialValue: highlighted)
        self._cameraPosition = State(initialValue: Self.initialCamera(for: points))
    }

    var body: some View {
        Map(position: $cameraPosition) {
            ForEach(points) { point in
                Annotation("", coordinate: point.coordinate) {
                    annotationDot(for: point)
                }
            }
        }
        .mapStyle(.standard(elevation: .realistic))
        .navigationTitle("Survey Map")
        .navigationBarTitleDisplayMode(.inline)
        .overlay(alignment: .bottomLeading) {
            legend
        }
        .safeAreaInset(edge: .bottom) {
            if let point = points.first(where: { $0.id == selectedID }) {
                detailCard(point)
            }
        }
    }

    // MARK: - Annotation

    @ViewBuilder
    private func annotationDot(for point: SurveyPoint) -> some View {
        let color = rssiColor(for: point.meanRSSI)
        let selected = point.id == selectedID
        ZStack {
            Circle()
                .fill(color.opacity(0.2))
                .frame(width: selected ? 44 : 28)
            Circle()
                .fill(color)
                .frame(width: selected ? 20 : 12)
            if selected {
                Circle()
                    .stroke(color, lineWidth: 2.5)
                    .frame(width: 44)
            }
        }
        .animation(.spring(duration: 0.2), value: selected)
        .onTapGesture {
            selectedID = selectedID == point.id ? nil : point.id
        }
    }

    // MARK: - Detail card

    @ViewBuilder
    private func detailCard(_ point: SurveyPoint) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(point.timestamp, style: .date)
                        .font(.subheadline.weight(.semibold))
                    Text(point.timestamp, style: .time)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    selectedID = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 14) {
                Label(
                    String(format: "%.1f dBm", point.meanRSSI),
                    systemImage: "wifi"
                )
                .foregroundStyle(rssiColor(for: point.meanRSSI))

                Label("\(point.sampleCount) samples", systemImage: "waveform.path")
                    .foregroundStyle(.secondary)

                let weakCount = point.weakDevices.isEmpty ? 0
                    : point.weakDevices.split(separator: ",").count
                if weakCount > 0 {
                    Label("\(weakCount) weak", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
            }
            .font(.caption)

            Text(String(format: "%.5f, %.5f",
                        point.coordinate.latitude, point.coordinate.longitude))
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.tertiary)
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
        .padding(.bottom, 6)
    }

    // MARK: - Legend

    private var legend: some View {
        HStack(spacing: 8) {
            ForEach([
                ("≥ −50", Color.green),
                ("−65", Color.yellow),
                ("−80", Color.orange),
                ("< −80", Color.red),
            ], id: \.0) { label, color in
                HStack(spacing: 3) {
                    Circle().fill(color).frame(width: 8, height: 8)
                    Text(label).font(.system(size: 9))
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
        .padding(.leading, 12)
        .padding(.bottom, selectedID == nil ? 12 : 130)
        .animation(.easeInOut(duration: 0.2), value: selectedID)
    }

    // MARK: - Helpers

    private func rssiColor(for rssi: Double) -> Color {
        if rssi < -80 { return .red }
        if rssi < -65 { return .orange }
        if rssi < -50 { return .yellow }
        return .green
    }

    private static func initialCamera(for points: [SurveyPoint]) -> MapCameraPosition {
        guard !points.isEmpty else { return .automatic }
        let lats = points.map(\.latitude)
        let lngs = points.map(\.longitude)
        let centerLat = (lats.min()! + lats.max()!) / 2
        let centerLng = (lngs.min()! + lngs.max()!) / 2
        let spanLat = max((lats.max()! - lats.min()!) * 2.0, 0.004)
        let spanLng = max((lngs.max()! - lngs.min()!) * 2.0, 0.004)
        return .region(MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: centerLat, longitude: centerLng),
            span: MKCoordinateSpan(latitudeDelta: spanLat, longitudeDelta: spanLng)
        ))
    }
}
