import Foundation
import Observation
import CoreLocation

@Observable
final class SurveySessionManager {
    var activeSession: SurveySession
    private var samples: [SurveySample] = []
    var currentMeanRSSI: Double?
    var currentWeakIDs: [String] = []
    private(set) var lastKnownLocation: CLLocationCoordinate2D?
    var sampleCount: Int { samples.count }

    @ObservationIgnored
    private let locationTracker = LocationTracker()

    init() {
        activeSession = SurveySession(startedAt: Date())
        locationTracker.onLocationUpdate = { [weak self] coord in
            self?.lastKnownLocation = coord
        }
    }

    func recordSample(deviceID: String, rssi: Int, location: CLLocationCoordinate2D?) {
        let finalLocation: CLLocationCoordinate2D
        if let location {
            finalLocation = location
            lastKnownLocation = location
        } else if let last = locationTracker.currentCoordinate ?? lastKnownLocation {
            finalLocation = last
        } else {
            // Apple Park as fallback — visible indicator that real location is unavailable
            finalLocation = CLLocationCoordinate2D(latitude: 37.3346, longitude: -122.0090)
        }
        samples.append(SurveySample(deviceID: deviceID, rssi: rssi, location: finalLocation))
        currentMeanRSSI = samples.map { Double($0.rssi) }.reduce(0, +) / Double(samples.count)
        currentWeakIDs = samples.filter { $0.rssi < -80 }.map(\.deviceID)
    }

    func startSession() {
        activeSession = SurveySession(startedAt: Date())
        samples.removeAll()
        currentMeanRSSI = nil
        currentWeakIDs = []
        locationTracker.startTracking()
    }

    func endSession() -> SurveyPoint? {
        locationTracker.stopTracking()
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

// MARK: - Supporting types

struct SurveySession {
    let startedAt: Date
}

struct SurveySample {
    let deviceID: String
    let rssi: Int
    let location: CLLocationCoordinate2D
}

// MARK: - LocationTracker (private NSObject wrapper for CLLocationManagerDelegate)

final class LocationTracker: NSObject {
    var onLocationUpdate: ((CLLocationCoordinate2D) -> Void)?
    private(set) var currentCoordinate: CLLocationCoordinate2D?

    @ObservationIgnored
    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        manager.requestWhenInUseAuthorization()
    }

    func startTracking() {
        manager.startUpdatingLocation()
    }

    func stopTracking() {
        manager.stopUpdatingLocation()
    }
}

extension LocationTracker: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let coord = locations.last?.coordinate else { return }
        currentCoordinate = coord
        onLocationUpdate?(coord)
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.startUpdatingLocation()
        default:
            break
        }
    }
}
