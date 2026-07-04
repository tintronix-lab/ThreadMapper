import SwiftUI

struct DeviceDetailView: View {
    let device: ThreadDevice
    @Environment(\.dismiss) private var dismiss
    @Environment(SurveyViewModel.self) private var surveyVM

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Identity")) {
                    LabeledContent("Name", value: device.name)
                    LabeledContent("Manufacturer", value: device.manufacturer)
                    LabeledContent("Product", value: device.productName)
                    LabeledContent("Type", value: device.deviceType)
                }
                Section(header: Text("Thread")) {
                    LabeledContent("Border Router", value: device.isBorderRouter ? "Yes" : "No")
                    LabeledContent("Router", value: device.isRouter ? "Yes" : "No")
                    LabeledContent("Sleepy End Device", value: device.isSleepyEndDevice ? "Yes" : "No")
                    if let parent = device.parentNodeID { LabeledContent("Parent", value: parent) }
                    if let ch = device.channel { LabeledContent("Channel", value: "\(ch)") }
                }
                Section(header: Text("Status")) {
                    if let rssi = device.rssi {
                        LabeledContent("RSSI", value: "\(rssi) dBm")
                    }
                    if let batt = device.batteryPercentage {
                        LabeledContent("Battery", value: "\(batt)%")
                    }
                }

                Section("Survey") {
                    Button("Export CSV for This Device") {
                        _ = surveyVM.exportCSV(for: device.name)
                    }

                    NavigationLink("Survey History") {
                        DeviceSurveyHistory(deviceID: device.name)
                    }
                }
            }
            .navigationTitle(device.name)
            .toolbar { ToolbarItem(placement: .primaryAction) { Button("Done") { dismiss() } } }
        }
    }
}
