import Foundation
import Observation
import CoreLocation

@Observable
final class SurveySessionManager {
    var activeSession: SurveySession
    private var samples: [SurveySample] = []
    var currentMeanRSSI: Double?
    var currentWeakIDs: [String] = []

    init() {
        activeSession = SurveySession(startedAt: Date())
        samples.removeAll()
    }

    func recordSample(deviceID: String, rssi: Int, location: CLLocationCoordinate2D) {
        samples.append(SurveySample(deviceID: deviceID, rssi: rssi, location: location))
        currentMeanRSSI = samples.map { Double($0.rssi) }.reduce(0, +) / Double(samples.count)
        currentWeakIDs = samples.filter { $0.rssi < -80 }.map(\.deviceID)
    }

    func startSession() {
        activeSession = SurveySession(startedAt: Date())
        samples.removeAll()
        currentMeanRSSI = nil
        currentWeakIDs = []
    }

    func endSession() -> SurveyPoint? {
        guard !samples.isEmpty else { return nil }
        let meanRSSI = samples.map { Double($0.rssi) }.reduce(0, +) / Double(samples.count)
        let weakIDs = samples.filter { $0.rssi < -80 }.map(\.deviceID)
        let coord = samples.first?.location ?? CLLocationCoordinate2D(latitude: 0, longitude: 0)

        let point = SurveyPoint(
            coordinate: coord,
            meanRSSI: meanRSSI,
            weakDevices: weakIDs,
            sampleCount: samples.count
        )
        samples.removeAll()
        currentMeanRSSI = nil
        currentWeakIDs = []
        return point
    }
}

struct SurveySession {
    let startedAt: Date
}

struct SurveySample {
    let deviceID: String
    let rssi: Int
    let location: CLLocationCoordinate2D
}
