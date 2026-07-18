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

            result[id] = DeviceAnomaly(
                deviceID: id,
                trajectory: trajectory,
                deviationScore: deviationScore,
                baselineMean: baselineMean,
                recentMean: recentMean,
                readingCount: n
            )
        }
        return result
    }
}
