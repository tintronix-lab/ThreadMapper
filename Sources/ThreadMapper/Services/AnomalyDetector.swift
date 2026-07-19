import Foundation

// MARK: - Types

enum DeviceTrajectory: Comparable {
    case stable
    case declining
    case critical

    var label: LocalizedStringResource {
        switch self {
        case .stable:    return "Stable"
        case .declining: return "Declining"
        case .critical:  return "Critical"
        }
    }

    var sfSymbol: String {
        switch self {
        case .stable:   return "arrow.right"
        case .declining: return "arrow.down.right"
        case .critical: return "arrow.down.to.line"
        }
    }
}

struct DeviceAnomaly {
    let deviceID: UUID
    let trajectory: DeviceTrajectory
    /// Positive = recent signal is worse than baseline, in standard deviations.
    let deviationScore: Double
    let baselineMean: Double   // dBm
    let recentMean: Double     // dBm
    let readingCount: Int
    /// Hours until signal reaches a deeply critical level at the current linear rate of decline.
    /// Nil when trajectory is stable, slope is near-zero, or projection exceeds 14 days.
    let projectedHoursToFailure: Double?

    var dropDelta: Double { baselineMean - recentMean }   // positive = dropped
}

// MARK: - Detector

/// Pure-function anomaly detection over DeviceStatsStore readings.
/// Compares a rolling recent window against the historical baseline for each device.
enum AnomalyDetector {

    private static let minReadings   = 12
    private static let recentWindow  = 6   // last 6 samples (~30 s at 5 s poll)
    private static let decliningThreshold = 1.5   // std-devs below baseline → declining
    private static let criticalThreshold  = 3.0   // std-devs below baseline → critical

    /// Analyse all provided device IDs against stored readings.
    /// Call on the main actor since DeviceStatsStore is @MainActor.
    static func analyzeAll(
        readingsByKey: [String: [DeviceStatsStore.Reading]],
        deviceIDs: [UUID]
    ) -> [UUID: DeviceAnomaly] {
        var result: [UUID: DeviceAnomaly] = [:]
        for id in deviceIDs {
            guard let readings = readingsByKey[id.uuidString],
                  readings.count >= minReadings else { continue }

            let values = readings.map { Double($0.rssi) }
            let n      = values.count

            let baselineValues = Array(values.dropLast(recentWindow))
            let recentValues   = Array(values.suffix(recentWindow))

            guard !baselineValues.isEmpty else { continue }

            let baselineMean = baselineValues.reduce(0, +) / Double(baselineValues.count)
            let recentMean   = recentValues.reduce(0, +)   / Double(recentValues.count)

            let variance = baselineValues
                .map { pow($0 - baselineMean, 2) }
                .reduce(0, +) / Double(baselineValues.count)
            let stddev = max(sqrt(variance), 2.0)   // floor at 2 dBm to avoid noise over-sensitivity

            let deviationScore = (baselineMean - recentMean) / stddev

            let trajectory: DeviceTrajectory
            if deviationScore >= criticalThreshold {
                trajectory = .critical
            } else if deviationScore >= decliningThreshold {
                trajectory = .declining
            } else {
                trajectory = .stable
            }

            let projection: Double? = trajectory != .stable
                ? projectHoursToFailure(readings: readings, baselineMean: baselineMean, stddev: stddev, currentMean: recentMean)
                : nil

            result[id] = DeviceAnomaly(
                deviceID: id,
                trajectory: trajectory,
                deviationScore: deviationScore,
                baselineMean: baselineMean,
                recentMean: recentMean,
                readingCount: n,
                projectedHoursToFailure: projection
            )
        }
        return result
    }

    /// OLS linear regression over all readings to estimate slope (units/second).
    /// Projects from `currentMean` to `baselineMean - 4σ` and returns hours.
    /// Returns nil if slope is near-zero, projection is negative, or > 14 days (too uncertain).
    private static func projectHoursToFailure(
        readings: [DeviceStatsStore.Reading],
        baselineMean: Double,
        stddev: Double,
        currentMean: Double
    ) -> Double? {
        let targetValue = baselineMean - 4.0 * stddev
        guard currentMean > targetValue else { return nil }

        let n = Double(readings.count)
        let times = readings.map { $0.timestamp.timeIntervalSince1970 }
        let values = readings.map { Double($0.rssi) }

        let meanTime = times.reduce(0, +) / n
        let meanVal  = values.reduce(0, +) / n

        let numerator   = zip(times, values).reduce(0.0) { $0 + ($1.0 - meanTime) * ($1.1 - meanVal) }
        let denominator = times.reduce(0.0) { $0 + pow($1 - meanTime, 2) }

        guard denominator > 0 else { return nil }
        let slopePerSecond = numerator / denominator
        guard slopePerSecond < -0.0001 else { return nil }   // ignore near-zero / upward slopes

        let secondsToTarget = (currentMean - targetValue) / (-slopePerSecond)
        let hours = secondsToTarget / 3600.0

        guard hours > 0, hours <= 336 else { return nil }   // cap at 14 days
        return max(0.5, hours)                               // floor at 30 minutes
    }
}
