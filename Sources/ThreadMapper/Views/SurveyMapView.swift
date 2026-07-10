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
                Label(Int(point.meanRSSI.rounded()).rssiQualityLabel, systemImage: "wifi")
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

            if let room = point.room {
                Label(room, systemImage: TMStyle.roomIcon(room))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
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
                ("−50…−65", Color.mint),
                ("−65…−80", Color.orange),
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

    // Uses the shared RSSI → color scale (SignalStrength.swift) so the map
    // matches the Dashboard, device detail, and mesh graph.
    private func rssiColor(for rssi: Double) -> Color {
        Int(rssi.rounded()).rssiColor
    }

    private static func initialCamera(for points: [SurveyPoint]) -> MapCameraPosition {
        let lats = points.map(\.latitude)
        let lngs = points.map(\.longitude)
        guard let minLat = lats.min(), let maxLat = lats.max(),
              let minLng = lngs.min(), let maxLng = lngs.max() else { return .automatic }
        let centerLat = (minLat + maxLat) / 2
        let centerLng = (minLng + maxLng) / 2
        let spanLat = max((maxLat - minLat) * 2.0, 0.004)
        let spanLng = max((maxLng - minLng) * 2.0, 0.004)
        return .region(MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: centerLat, longitude: centerLng),
            span: MKCoordinateSpan(latitudeDelta: spanLat, longitudeDelta: spanLng)
        ))
    }
}
