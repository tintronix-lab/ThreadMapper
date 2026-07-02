import SwiftUI
import Observation

struct SurveyWalkView: View {
    @State private var viewModel: SurveyViewModel

    init() {
        _viewModel = State(initialValue: SurveyViewModel())
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Button {
                        viewModel.toggleRecording()
                    } label: {
                        Label(viewModel.isRecording ? "Stop Survey" : "Start Survey",
                              systemImage: viewModel.isRecording ? "stop.circle.fill" : "record.circle")
                    }
                    .tint(viewModel.isRecording ? .red : .green)
                }

                Section("Current Reading") {
                    if let rssi = viewModel.currentRSSI {
                        Text("RSSI: \(rssi) dBm").font(.system(.body, design: .monospaced))
                    } else {
                        Text("No readings yet").foregroundStyle(.secondary)
                    }
                }

                Section("Weak Links") {
                    ForEach(viewModel.weakDevices) { device in
                        Text(device.name)
                    }
                }
            }
            .navigationTitle("Survey Walk")
        }
    }
}
