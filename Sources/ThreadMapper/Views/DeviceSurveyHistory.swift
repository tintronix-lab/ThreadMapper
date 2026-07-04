import SwiftUI
import CoreLocation
import Observation

struct DeviceSurveyHistory: View {
    let deviceID: String
    @Environment(SurveyViewModel.self) private var viewModel

    var body: some View {
        List(viewModel.surveys(for: deviceID)) { point in
            VStack(alignment: .leading, spacing: 4) {
                Text(point.timestamp, style: .date)
                Text(String(format: "%.5f, %.5f", point.coordinate.latitude, point.coordinate.longitude))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("RSSI \(String(format: "%.1f", point.meanRSSI)) • \(point.sampleCount) sample(s)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("History")
    }
}
