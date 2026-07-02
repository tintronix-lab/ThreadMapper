import Foundation
import SwiftData
import Observation
import CoreLocation

@Observable
final class SurveySessionManager {
    var activeSession: SurveySession?
    private var samples: [SurveySample] = []

    func startSession() {
        activeSession = SurveySession(startedAt: Date())
        samples.removeAll()
    }

    func recordSample(deviceID: String, rssi: Int, location: CLLocationCoordinate2D) {
        samples.append(SurveySample(deviceID: deviceID, rssi: rssi, location: location))
    }

    func endSession() -> SurveyPoint? {
        guard let session = activeSession, !samples.isEmpty else { return nil }
        let meanRSSI = samples.map(\.rssi).reduce(0, +) / Double(samples.count)
        let weak = samples.filter { $0.rssi < -80 }.map(\.deviceID)
        let coord = samples.first?.location ?? CLLocationCoordinate2D(latitude: 0, longitude: 0)

        let point = SurveyPoint(
            coordinate: coord,
            meanRSSI: meanRSSI,
            weakDevices: weak,
            sampleCount: samples.count
        )
        activeSession = nil
        samples.removeAll()
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
