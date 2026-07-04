import Foundation
import CoreLocation

struct Extrapolator {
    static func interpolateRSSI(samples: [Int]) -> Double? {
        guard samples.count >= 3 else { return nil }
        let sorted = samples.sorted()
        let trimmed = sorted.dropFirst(max(1, samples.count / 10)).dropLast(max(1, samples.count / 10))
        guard !trimmed.isEmpty else { return nil }
        return Double(trimmed.reduce(0, +)) / Double(trimmed.count)
    }

    static func clusterDevices(_ devices: [ThreadDevice], radius: CLLocationDistance = 30.0) -> [[ThreadDevice]] {
        var clusters: [[ThreadDevice]] = []
        var remaining = devices

        while !remaining.isEmpty {
            let seed = remaining.removeFirst()
            var cluster: [ThreadDevice] = [seed]
            var nearby: [ThreadDevice] = []

            for candidate in remaining {
                if let seedCoord = seed.roomCoordinate,
                   let candCoord = candidate.roomCoordinate {
                    let dist = haversine(a: seedCoord, b: candCoord)
                    if dist <= radius { cluster.append(candidate) }
                    else { nearby.append(candidate) }
                } else {
                    nearby.append(candidate)
                }
            }
            remaining = nearby
            clusters.append(cluster)
        }
        return clusters
    }

    static func haversine(a: CLLocationCoordinate2D, b: CLLocationCoordinate2D) -> CLLocationDistance {
        let R = 6371000.0
        let φ1 = a.latitude * .pi / 180
        let φ2 = b.latitude * .pi / 180
        let Δφ = (b.latitude - a.latitude) * .pi / 180
        let Δλ = (b.longitude - a.longitude) * .pi / 180
        let sinΔφ = sin(Δφ / 2)
        let cosφ1φ2 = cos(φ1) * cos(φ2)
        let sinΔλ = sin(Δλ / 2)
        let h = sinΔφ * sinΔφ + cosφ1φ2 * sinΔλ * sinΔλ
        return R * 2 * asin(min(1, sqrt(h)))
    }
}

extension ThreadDevice {
    var roomCoordinate: CLLocationCoordinate2D? {
        guard let room = room else { return nil }
        switch room.lowercased() {
        case "living room": return CLLocationCoordinate2D(latitude: 0, longitude: 0)
        case "kitchen": return CLLocationCoordinate2D(latitude: 0.001, longitude: 0.0)
        case "bedroom": return CLLocationCoordinate2D(latitude: -0.001, longitude: 0.0)
        default: return nil
        }
    }
}
