import SwiftUI
import CoreLocation
import Observation

struct SavedSurveyList: View {
    @Environment(SurveyViewModel.self) private var viewModel
    @State private var selectedPoint: SurveyPoint?

    var body: some View {
        List {
            ForEach(viewModel.dedupedSavedPoints()) { point in
                Button {
                    selectedPoint = point
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(point.timestamp, style: .date)
                        Text("\(String(format: "%.5f, %.5f", point.coordinate.latitude, point.coordinate.longitude))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text("RSSI \(String(format: "%.1f", point.meanRSSI)) • \(point.sampleCount) sample(s)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Saved Surveys")
        .sheet(item: $selectedPoint) { point in
            NavigationStack {
                SurveyMapView(points: [point])
                    .toolbar {
                        ToolbarItem(placement: .primaryAction) {
                            Button("Done") { selectedPoint = nil }
                        }
                    }
            }
        }
    }
}
