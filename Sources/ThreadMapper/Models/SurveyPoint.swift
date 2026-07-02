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

    init(id: UUID = UUID(), coordinate: CLLocationCoordinate2D,
         meanRSSI: Double, weakDevices: [String], sampleCount: Int = 1,
         note: String? = nil) {
        self.id = id
        self.latitude = coordinate.latitude
        self.longitude = coordinate.longitude
        self.sampleCount = sampleCount
        self.meanRSSI = meanRSSI
        self.weakDevices = weakDevices.joined(separator: ",")
        self.timestamp = Date()
        self.note = note
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
