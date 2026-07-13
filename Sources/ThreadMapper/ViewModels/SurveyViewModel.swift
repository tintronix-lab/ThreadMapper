import SwiftUI
import CoreLocation
import Observation

@Observable
final class SurveyViewModel {
    var isRecording = false
    var currentRSSI: Int?
    var weakDevices: [WeakDevice] = []
    // Stored so @Observable tracks them (computed props through @ObservationIgnored manager don't propagate)
    var sessionSampleCount: Int = 0
    var sessionWeakCount: Int = 0
    var locationStatus: String = "No location fix"

    @ObservationIgnored
    private let manager = SurveySessionManager()
    // Observed (not @ObservationIgnored) so SavedSurveyList, section headers,
    // and counts refresh when sessions are saved or deleted.
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

    func toggleRecording(room: String? = nil) {
        if isRecording {
            if let point = manager.endSession(room: room) {
                savedPoints.append(point)
            }
            isRecording = false
            currentRSSI = nil
            weakDevices.removeAll()
            sessionSampleCount = 0
            sessionWeakCount = 0
        } else {
            manager.startSession()
            isRecording = true
        }
    }

    func record(deviceID: String, rssi: Int, location: CLLocationCoordinate2D) {
        manager.recordSample(deviceID: deviceID, rssi: rssi, location: location)
        currentRSSI = rssi
        syncSessionStats()
        if rssi < -80, !weakDevices.contains(where: { $0.name == deviceID }) {
            weakDevices.append(WeakDevice(name: deviceID, rssi: rssi))
        }
    }

    /// Called periodically by the view while recording; location is resolved internally by the manager.
    func recordCurrentDevices(_ devices: [ThreadDevice]) {
        guard isRecording, !devices.isEmpty else { return }
        var lastRSSI: Int?
        for device in devices {
            let rssi = device.rssi ?? -65
            manager.recordSample(deviceID: device.name, rssi: rssi, location: nil)
            lastRSSI = rssi
            if rssi < -80, !weakDevices.contains(where: { $0.name == device.name }) {
                weakDevices.append(WeakDevice(name: device.name, rssi: rssi))
            }
        }
        currentRSSI = lastRSSI
        syncSessionStats()
    }

    func resetSession() {
        manager.startSession()
        currentRSSI = nil
        weakDevices.removeAll()
        sessionSampleCount = 0
        sessionWeakCount = 0
    }

    private func syncSessionStats() {
        sessionSampleCount = manager.sampleCount
        sessionWeakCount = manager.currentWeakIDs.count
        if let coord = manager.lastKnownLocation {
            locationStatus = String(format: "%.4f, %.4f", coord.latitude, coord.longitude)
        }
    }

    func exportCSVURL() -> URL? {
        let points = savedPoints
        guard !points.isEmpty else { return nil }
        let header = "timestamp,latitude,longitude,meanRSSI,weakDevices,sampleCount\n"
        let rows = points.map { point in
            let ts = Self.isoFormatter.string(from: point.timestamp)
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
        let points = savedPoints.filter { $0.weakDeviceList.contains(deviceID) }
        guard !points.isEmpty else { return nil }
        let header = "timestamp,latitude,longitude,meanRSSI,weakDevices,sampleCount\n"
        let rows = points.map { point in
            let ts = Self.isoFormatter.string(from: point.timestamp)
            let weaks = point.weakDevices.replacingOccurrences(of: ",", with: ";")
            return "\(ts),\(point.latitude),\(point.longitude),\(point.meanRSSI),\"\(weaks)\",\(point.sampleCount)"
        }.joined(separator: "\n")
        let content = header + rows
        // Sanitize the device name — "/" or ":" in accessory names would break the path
        let safeName = deviceID.components(separatedBy: .init(charactersIn: "/:\\?%*|\"<>")).joined(separator: "-")
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("threadmapper_survey_\(safeName)_\(Date().timeIntervalSince1970).csv")
        try? content.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    func loadRecentSamplePoints(completion: ([SurveyPoint]) -> Void) {
        completion(savedPoints)
    }

    var savedPointCount: Int { savedPoints.count }
    var hasSavedPoints: Bool { !savedPoints.isEmpty }
    var hasWeakDevices: Bool { !weakDevices.isEmpty }

    var lastSavedFocus: CLLocationCoordinate2D? {
        savedPoints.last?.coordinate
    }

    func focus(for deviceID: String) -> CLLocationCoordinate2D? {
        savedPoints.filter { $0.weakDeviceList.contains(deviceID) }.last?.coordinate
    }

    func exportURLForCurrentSession() -> URL? { exportCSVURL() }

    func exportURLForCurrentSessionPerDevice() -> URL? {
        guard let first = weakDevices.first else { return nil }
        return exportCSV(for: first.name)
    }

    func surveys(for deviceID: String) -> [SurveyPoint] {
        savedPoints.filter { $0.weakDeviceList.contains(deviceID) }
    }

    var locationStatusLabel: String { locationStatus }

    /// Per-room signal quality aggregated from saved survey points that have a room tag.
    /// Sorted best-first (highest avgRSSI).
    func roomStats() -> [(room: String, avgRSSI: Double, sampleCount: Int)] {
        let grouped = Dictionary(grouping: savedPoints.filter { $0.room != nil }) { $0.room! }
        return grouped.map { room, points in
            let avgRSSI = points.map(\.meanRSSI).reduce(0, +) / Double(points.count)
            let totalSamples = points.map(\.sampleCount).reduce(0, +)
            return (room: room, avgRSSI: avgRSSI, sampleCount: totalSamples)
        }.sorted { $0.avgRSSI > $1.avgRSSI }
    }

    /// Unique weak-device names across saved points for the given rooms.
    func weakDeviceNames(for rooms: Set<String>) -> [String] {
        let relevant = savedPoints.filter { pt in
            guard let room = pt.room else { return false }
            return rooms.contains(room)
        }
        return Array(Set(relevant.flatMap(\.weakDeviceList))).sorted()
    }

    // Convenience wrapper used by SurveyWalkView
    func signalQuality(for rssi: Int) -> (label: String, color: Color) {
        (rssi.rssiQualityLabel, rssi.rssiColor)
    }

    func deleteSavedPoints(at offsets: IndexSet) {
        savedPoints.remove(atOffsets: offsets)
    }

    func deleteAllSavedPoints() {
        savedPoints.removeAll()
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

    nonisolated(unsafe) private static let isoFormatter = ISO8601DateFormatter()

    private func persist() {
        do {
            let payload: [[String: Any]] = savedPoints.map { point in
                var dict: [String: Any] = [
                    "timestamp": Self.isoFormatter.string(from: point.timestamp),
                    "latitude": point.latitude,
                    "longitude": point.longitude,
                    "meanRSSI": point.meanRSSI,
                    // Store as [String] array so restore can cast with as? [String]
                    "weakDevices": point.weakDeviceList,
                    "sampleCount": point.sampleCount
                ]
                if let room = point.room { dict["room"] = room }
                return dict
            }
            let data = try JSONSerialization.data(withJSONObject: payload, options: [])
            try data.write(to: storeURL, options: [.atomic, .completeFileProtection])
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
                timestamp: ts,
                room: dict["room"] as? String
            )
        }
    }
}
