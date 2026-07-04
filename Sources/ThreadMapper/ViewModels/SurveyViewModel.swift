import SwiftUI
import CoreLocation
import Observation

@Observable
final class SurveyViewModel {
    var isRecording = false
    var currentRSSI: Int?
    var weakDevices: [WeakDevice] = []

    @ObservationIgnored
    private let manager = SurveySessionManager()
    @ObservationIgnored
    private var savedPoints: [SurveyPoint] = [] {
        didSet { persist() }
    }
    @ObservationIgnored
    private let storeURL: URL = {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documents.appendingPathComponent("surveys.json")
    }()

    init() {
        restore()
    }

    func toggleRecording() {
        if isRecording {
            if let point = manager.endSession() {
                savedPoints.append(point)
            }
            isRecording = false
            currentRSSI = nil
            weakDevices.removeAll()
        } else {
            manager.startSession()
            isRecording = true
        }
    }

    func record(deviceID: String, rssi: Int, location: CLLocationCoordinate2D) {
        manager.recordSample(deviceID: deviceID, rssi: rssi, location: location)
        currentRSSI = rssi
        if rssi < -80 {
            weakDevices.append(WeakDevice(name: deviceID, rssi: rssi))
        }
    }

    func resetSession() {
        manager.startSession()
        currentRSSI = nil
        weakDevices.removeAll()
    }

    func exportCSVURL() -> URL? {
        let points = savedPoints
        guard !points.isEmpty else { return nil }
        let header = "timestamp,latitude,longitude,meanRSSI,weakDevices,sampleCount\n"
        let rows = points.map { point in
            let ts = ISO8601DateFormatter().string(from: point.timestamp)
            let weaks = point.weakDevices.replacingOccurrences(of: ",", with: ";")
            return "\(ts),\(point.latitude),\(point.longitude),\(point.meanRSSI),\"\(weaks)\",\(point.sampleCount)"
        }.joined(separator: "\n")
        let content = header + rows
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("threadmapper_survey_\(Date().timeIntervalSince1970).csv")
        try? content.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    func exportCSV(for deviceID: String) -> URL? {
        let points = savedPoints.filter { $0.weakDevices.contains(deviceID) }
        guard !points.isEmpty else { return nil }
        let header = "timestamp,latitude,longitude,meanRSSI,weakDevices,sampleCount\n"
        let rows = points.map { point in
            let ts = ISO8601DateFormatter().string(from: point.timestamp)
            let weaks = point.weakDevices.replacingOccurrences(of: ",", with: ";")
            return "\(ts),\(point.latitude),\(point.longitude),\(point.meanRSSI),\"\(weaks)\",\(point.sampleCount)"
        }.joined(separator: "\n")
        let content = header + rows
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("threadmapper_survey_\(deviceID)_\(Date().timeIntervalSince1970).csv")
        try? content.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    func loadRecentSamplePoints(completion: @escaping ([SurveyPoint]) -> Void) {
        let points = savedPoints
        Task { @MainActor in
            completion(points)
        }
    }

    var sessionSampleCount: Int { manager.sampleCount }
    var sessionWeakCount: Int { manager.currentWeakIDs.count }
    var savedPointCount: Int { savedPoints.count }
    var hasSavedPoints: Bool { !savedPoints.isEmpty }
    var hasWeakDevices: Bool { !weakDevices.isEmpty }

    var lastSavedFocus: CLLocationCoordinate2D? {
        savedPoints.last?.coordinate
    }

    func focus(for deviceID: String) -> CLLocationCoordinate2D? {
        savedPoints.filter { $0.weakDevices.contains(deviceID) }.last?.coordinate
    }

    func exportURLForCurrentSession() -> URL? { exportCSVURL() }

    func exportURLForCurrentSessionPerDevice() -> URL? {
        guard let first = weakDevices.first else { return nil }
        return exportCSV(for: first.name)
    }

    func surveys(for deviceID: String) -> [SurveyPoint] {
        savedPoints.filter { $0.weakDevices.contains(deviceID) }
    }

    var locationStatusLabel: String {
        if let coord = manager.lastKnownLocation {
            let lat = String(format: "%.4f", coord.latitude)
            let lng = String(format: "%.4f", coord.longitude)
            return "Last fix: \(lat), \(lng)"
        }
        return "No location fix"
    }

    // Convenience wrapper used by SurveyWalkView
    func signalQuality(for rssi: Int) -> (label: String, color: Color) {
        (rssi.rssiQualityLabel, rssi.rssiColor)
    }

    func dedupedSavedPoints() -> [SurveyPoint] {
        var seenIDs: Set<String> = []
        return savedPoints.filter { point in
            let id = "\(point.timestamp.timeIntervalSince1970)-\(point.latitude)-\(point.longitude)"
            if seenIDs.contains(id) { return false }
            seenIDs.insert(id)
            return true
        }
    }

    // MARK: - Persistence

    private static let isoFormatter = ISO8601DateFormatter()

    private func persist() {
        do {
            let payload: [[String: Any]] = savedPoints.map { point in
                [
                    "timestamp": Self.isoFormatter.string(from: point.timestamp),
                    "latitude": point.latitude,
                    "longitude": point.longitude,
                    "meanRSSI": point.meanRSSI,
                    // Store as [String] array so restore can cast with as? [String]
                    "weakDevices": point.weakDevices.isEmpty
                        ? [String]()
                        : point.weakDevices.split(separator: ",").map(String.init),
                    "sampleCount": point.sampleCount
                ]
            }
            let data = try JSONSerialization.data(withJSONObject: payload, options: [])
            try data.write(to: storeURL, options: [.atomic])
        } catch {
            print("Survey persist failed: \(error)")
        }
    }

    private func restore() {
        guard let data = try? Data(contentsOf: storeURL),
              let raw = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return }
        savedPoints = raw.compactMap { dict -> SurveyPoint? in
            guard let tsString = dict["timestamp"] as? String,
                  let ts = Self.isoFormatter.date(from: tsString),
                  let lat = dict["latitude"] as? Double,
                  let lng = dict["longitude"] as? Double,
                  let mean = dict["meanRSSI"] as? Double,
                  let count = dict["sampleCount"] as? Int else { return nil }

            // Handle both old String format and new [String] array format
            let weakList: [String]
            if let arr = dict["weakDevices"] as? [String] {
                weakList = arr
            } else if let str = dict["weakDevices"] as? String {
                weakList = str.isEmpty ? [] : str.split(separator: ",").map(String.init)
            } else {
                weakList = []
            }

            return SurveyPoint(
                coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lng),
                meanRSSI: mean,
                weakDevices: weakList,
                sampleCount: count,
                timestamp: ts
            )
        }
    }
}
