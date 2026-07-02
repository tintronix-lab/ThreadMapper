import SwiftData
import CoreLocation

@Model
final class SurveyPoint {
    var id: UUID
    var coordinate: Data
    var sampleCount: Int
    var meanRSSI: Double
    var weakDevices: String
    var timestamp: Date
    var note: String?

    init(id: UUID = UUID(), coordinate: CLLocationCoordinate2D,
         meanRSSI: Double, weakDevices: [String], sampleCount: Int = 1,
         note: String? = nil) {
        self.id = id
        self.coordinate = try! JSONEncoder().encode(coordinate)
        self.sampleCount = sampleCount
        self.meanRSSI = meanRSSI
        self.weakDevices = weakDevices.joined(separator: ",")
        self.timestamp = Date()
        self.note = note
    }

    var decodedCoordinate: CLLocationCoordinate2D? {
        try? JSONDecoder().decode(CLLocationCoordinate2D.self, from: coordinate)
    }
}
