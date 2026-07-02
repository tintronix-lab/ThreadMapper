import SwiftUI

struct SurveyWalkView: View {
    @State private var viewModel: SurveyViewModel
    @State private var selectedDeviceID: String?

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
                        Text("RSSI: \(rssi) dBm").font(.monospacedDigit())
                    } else {
                        Text("No readings yet").foregroundStyle(.secondary)
                    }
                }

                Section("Weak Links") {
                    if viewModel.weakDevices.isEmpty {
                        Text("None")
                    } else {
                        ForEach(viewModel.weakDevices) { device in
                            Text(device.name)
                        }
                    }
                }
            }
            .navigationTitle("Survey Walk")
        }
    }
}

struct WeakDevice: Identifiable {
    let id = UUID()
    let name: String
}
