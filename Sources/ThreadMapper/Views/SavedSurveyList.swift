import SwiftUI
import CoreLocation
import Observation

struct SavedSurveyList: View {
    @Environment(SurveyViewModel.self) private var viewModel
    @State private var selectedPoint: SurveyPoint?
    @State private var showDeleteAllConfirm = false

    private var points: [SurveyPoint] { viewModel.dedupedSavedPoints() }

    var body: some View {
        List {
            ForEach(points) { point in
                Button {
                    selectedPoint = point
                } label: {
                    surveyRow(point)
                }
                .buttonStyle(.plain)
            }
            .onDelete { offsets in
                viewModel.deleteSavedPoints(at: offsets)
            }
        }
        .navigationTitle("Saved Surveys (\(points.count))")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if !points.isEmpty {
                    Button(role: .destructive) {
                        showDeleteAllConfirm = true
                    } label: {
                        Label("Delete All", systemImage: "trash")
                            .font(.caption)
                    }
                }
            }
            ToolbarItem(placement: .navigationBarLeading) {
                EditButton()
                    .font(.caption)
            }
        }
        .confirmationDialog(
            "Delete all \(points.count) survey sessions?",
            isPresented: $showDeleteAllConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete All", role: .destructive) {
                viewModel.deleteAllSavedPoints()
            }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(item: $selectedPoint) { point in
            NavigationStack {
                SurveyMapView(points: points, highlighted: point.id)
                    .toolbar {
                        ToolbarItem(placement: .primaryAction) {
                            Button("Done") { selectedPoint = nil }
                        }
                    }
            }
        }
    }

    @ViewBuilder
    private func surveyRow(_ point: SurveyPoint) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(point.timestamp, style: .date)
                    .font(.subheadline.weight(.medium))
                HStack(spacing: 8) {
                    if let room = point.room {
                        Label(room, systemImage: TMStyle.roomIcon(room))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Text(String(format: "%.4f, %.4f", point.coordinate.latitude, point.coordinate.longitude))
                        .font(.caption2)
                        .foregroundStyle(point.room == nil ? .secondary : .tertiary)
                }
                HStack(spacing: 8) {
                    Label(String(format: "%.1f dBm", point.meanRSSI), systemImage: "wifi")
                        .font(.caption2)
                        .foregroundStyle(Int(point.meanRSSI).rssiColor)
                    Text("· \(point.sampleCount) samples")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    if !point.weakDevices.isEmpty {
                        Text("· \(point.weakDevices.split(separator: ",").count) weak")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
    }
}
