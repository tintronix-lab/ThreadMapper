import SwiftUI
import Observation

struct DiagnosticRun: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    let score: Int              // 0–100 composite
    let criticalCount: Int
    let highCount: Int
    let mediumCount: Int
    let partitionCount: Int
    let isolatedDeviceCount: Int
    let borderRouterCount: Int
    let deviceCount: Int
}

@MainActor
@Observable
final class DiagnosticRunStore {
    static let shared = DiagnosticRunStore()

    private(set) var runs: [DiagnosticRun] = []  // newest first

    @ObservationIgnored private let maxRuns = 50
    @ObservationIgnored private let storeURL: URL = FileManager.default
        .urls(for: .documentDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("diagnostic_runs.json")

    private init() { restore() }

    func record(_ report: NetworkDiagnosticsEngine.Report) {
        let critical = report.recommendations.filter { $0.priority == .critical }.count
        let high     = report.recommendations.filter { $0.priority == .high }.count
        let medium   = report.recommendations.filter { $0.priority == .medium }.count
        let isolated = report.partitions.reduce(0) { $0 + $1.devices.count }
        let score    = max(0, 100 - critical * 20 - high * 10 - medium * 5 - isolated * 15)

        let run = DiagnosticRun(
            id: UUID(),
            timestamp: Date(),
            score: score,
            criticalCount: critical,
            highCount: high,
            mediumCount: medium,
            partitionCount: report.partitions.count,
            isolatedDeviceCount: isolated,
            borderRouterCount: report.totalBorderRouters,
            deviceCount: report.meshNodes.count
        )

        runs.insert(run, at: 0)
        if runs.count > maxRuns { runs.removeLast(runs.count - maxRuns) }
        persist()
    }

    func clearAll() {
        runs = []
        persist()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(runs) else { return }
        try? data.write(to: storeURL, options: [.atomic, .completeFileProtection])
    }

    private func restore() {
        guard let data = try? Data(contentsOf: storeURL),
              let decoded = try? JSONDecoder().decode([DiagnosticRun].self, from: data)
        else { return }
        runs = decoded
    }
}
