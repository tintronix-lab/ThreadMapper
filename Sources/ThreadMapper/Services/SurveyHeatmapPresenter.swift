import Foundation
import CoreLocation

struct SurveyHeatmapPresenter {
    struct Cell {
        var coordinate: CLLocationCoordinate2D
        var score: Double
        var weakDeviceCount: Int
    }

    static func present(
        points: [SurveyPoint],
        radiusMeters: CLLocationDistance = 35.0,
        resolutionMeters: CLLocationDistance = 12.0
    ) -> [Cell] {
        guard !points.isEmpty else { return [] }

        let bounds = boundingBox(for: points)

        var cells: [Cell] = []
        var lat = bounds.minLat
        while lat <= bounds.maxLat {
            var lng = bounds.minLng
            while lng <= bounds.maxLng {
                let coord = CLLocationCoordinate2D(latitude: lat, longitude: lng)
                var weightedSum = 0.0
                var weightTotal = 0.0
                var hits = 0

                for point in points {
                    let dist = haversine(coord, point.coordinate)
                    let weight = truncatedGaussian(dist, sigma: max(0.0001, radiusMeters))
                    if weight > 0 {
                        weightedSum += scoreForMeanRSSI(point.meanRSSI) * weight
                        weightTotal += weight
                        hits += point.weakDevices.isEmpty ? 0 : 1
                    }
                }

                if weightTotal > 0 {
                    cells.append(Cell(
                        coordinate: coord,
                        score: max(0.0, min(1.0, weightedSum / weightTotal)),
                        weakDeviceCount: hits
                    ))
                }

                lng += resolutionMeters / 111_320.0
            }
            lat += resolutionMeters / 110_540.0
        }

        return cells.sorted { $0.score < $1.score }
    }

    static func weakSpots(from cells: [Cell], threshold: Double = 0.35, limit: Int = 8) -> [Cell] {
        cells.filter { $0.score < threshold }.prefix(limit).map { $0 }
    }

    private static func boundingBox(for points: [SurveyPoint]) -> (minLat: Double, maxLat: Double, minLng: Double, maxLng: Double, size: Double) {
        let coords = points.map { $0.coordinate }
        let minLat = coords.map(\.latitude).min() ?? 0
        let maxLat = coords.map(\.latitude).max() ?? 0
        let minLng = coords.map(\.longitude).min() ?? 0
        let maxLng = coords.map(\.longitude).max() ?? 0
        // Add ~60m minimum spread so single-location surveys still produce heatmap cells
        let minDelta = 0.0006
        let padLat = max((maxLat - minLat) < minDelta ? minDelta / 2 : 0, 0)
        let padLng = max((maxLng - minLng) < minDelta ? minDelta / 2 : 0, 0)
        let pMinLat = minLat - padLat
        let pMaxLat = maxLat + padLat
        let pMinLng = minLng - padLng
        let pMaxLng = maxLng + padLng
        let size = max(pMaxLat - pMinLat, pMaxLng - pMinLng, minDelta)
        return (pMinLat, pMaxLat, pMinLng, pMaxLng, size)
    }

    private static func scoreForMeanRSSI(_ mean: Double) -> Double {
        max(0.0, min(1.0, (mean + 90.0) / 40.0))
    }

    private static func truncatedGaussian(_ x: CLLocationDistance, sigma: CLLocationDistance) -> Double {
        let sigma2 = sigma * sigma
        guard sigma2 > 0 else { return 0 }
        let value = exp(-(x * x) / (2 * sigma2))
        return x <= sigma ? value : 0.0
    }

    private static func haversine(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> CLLocationDistance {
        let R = 6_371_000.0
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

