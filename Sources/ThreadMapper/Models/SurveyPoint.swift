import Foundation
import CoreLocation
import Observation

@Observable
final class SurveyPoint: Identifiable {
    var id: UUID
    var latitude: Double
    var longitude: Double
    var sampleCount: Int
    var meanRSSI: Double
    var weakDevices: String
    var timestamp: Date
    var note: String?
    /// Room this session was recorded in (set by the guided survey).
    /// Rooms are the reliable indoor position signal — GPS is not.
    var room: String?

    init(id: UUID = UUID(), coordinate: CLLocationCoordinate2D,
         meanRSSI: Double, weakDevices: [String], sampleCount: Int = 1,
         timestamp: Date? = nil, note: String? = nil, room: String? = nil) {
        self.id = id
        self.latitude = coordinate.latitude
        self.longitude = coordinate.longitude
        self.sampleCount = sampleCount
        self.meanRSSI = meanRSSI
        self.weakDevices = weakDevices.joined(separator: ",")
        self.timestamp = timestamp ?? Date()
        self.note = note
        self.room = room
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    /// Weak device names as a list. Use this (not substring matching on
    /// `weakDevices`) so "Hub" never matches "Hub 2".
    var weakDeviceList: [String] {
        weakDevices.isEmpty ? [] : weakDevices.split(separator: ",").map(String.init)
    }
}