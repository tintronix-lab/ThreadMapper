import CoreLocation
import Foundation
import Observation

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
        let finalLocation: CLLocationCoordinate2D?
        if let location {
            finalLocation = location
            lastKnownLocation = location
        } else {
            // No fabricated fallback coordinates — a sample without a fix
            // stays location-less rather than poisoning the heatmap/exports.
            finalLocation = locationTracker.currentCoordinate ?? lastKnownLocation
        }
        samples.append(SurveySample(deviceID: deviceID, rssi: rssi, location: finalLocation))
        currentMeanRSSI = samples.map { Double($0.rssi) }.reduce(0, +) / Double(samples.count)
        currentWeakIDs = samples.filter { $0.rssi.isWeakRSSI }.map(\.deviceID)
    }

    func startSession() {
        activeSession = SurveySession(startedAt: Date())
        samples.removeAll()
        currentMeanRSSI = nil
        currentWeakIDs = []
        locationTracker.startTracking()
    }

    func endSession(room: String? = nil) -> SurveyPoint? {
        locationTracker.stopTracking()
        guard !samples.isEmpty else { return nil }
        let meanRSSI = samples.map { Double($0.rssi) }.reduce(0, +) / Double(samples.count)
        let weakIDs = samples.filter { $0.rssi.isWeakRSSI }.map(\.deviceID)
        defer {
            samples.removeAll()
            currentMeanRSSI = nil
            currentWeakIDs = []
        }
        // First real fix wins; fall back to the last known location.
        // If there was never a fix, discard rather than fabricate coordinates.
        guard let coord = samples.compactMap(\.location).first ?? lastKnownLocation else {
            return nil
        }
        return SurveyPoint(
            coordinate: coord,
            meanRSSI: meanRSSI,
            weakDevices: weakIDs,
            sampleCount: samples.count,
            room: room
        )
    }
}

// MARK: - Supporting types

struct SurveySession {
    let startedAt: Date
}

struct SurveySample {
    let deviceID: String
    let rssi: Int
    let location: CLLocationCoordinate2D?
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
        // Authorization is requested in startTracking() — contextually when a
        // survey begins — not at app launch just because this object exists.
    }

    func startTracking() {
        manager.requestWhenInUseAuthorization()
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
