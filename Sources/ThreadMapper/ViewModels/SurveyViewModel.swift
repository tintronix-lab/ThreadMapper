import Foundation
import Observation

@Observable
final class SurveyViewModel {
    var isRecording = false
    var currentRSSI: Int?
    var weakDevices: [ThreadDevice] = []

    private let manager = SurveySessionManager()

    func toggleRecording() {
        if isRecording {
            _ = manager.endSession()
            isRecording = false
        } else {
            manager.startSession()
            isRecording = true
        }
    }

    func record(deviceID: String, rssi: Int, location: CLLocationCoordinate2D) {
        manager.recordSample(deviceID: deviceID, rssi: rssi, location: location)
    }
}
