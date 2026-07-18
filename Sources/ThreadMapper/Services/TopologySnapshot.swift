import SwiftUI

// MARK: - Snapshot

struct TopologySnapshot: Codable, Identifiable {
    let id: UUID
    let capturedAt: Date
    let deviceStates: [DeviceState]
    let borderRouterCount: Int
    let totalDeviceCount: Int

    struct DeviceState: Codable {
        let deviceID: UUID
        let name: String
        let room: String?
        let hopCount: Int   // 99 = unreachable
        let rssi: Int?
        let isOffline: Bool
        let isBorderRouter: Bool
    }

    static func capture(report: NetworkDiagnosticsEngine.Report, devices: [ThreadDevice]) -> TopologySnapshot {
        let hopByID = Dictionary(uniqueKeysWithValues: report.deviceHops.map { ($0.device.id, $0.hopCount) })
        let states = devices.map { d in
            DeviceState(
                deviceID: d.id,
                name: d.name,
                room: d.room,
                hopCount: hopByID[d.id] ?? 99,
                rssi: d.rssi,
                isOffline: d.isOffline,
                isBorderRouter: d.isBorderRouter
            )
        }
        return TopologySnapshot(
            id: UUID(),
            capturedAt: Date(),
            deviceStates: states,
            borderRouterCount: report.totalBorderRouters,
            totalDeviceCount: devices.count
        )
    }

    func diff(against current: TopologySnapshot) -> SnapshotDiff {
        SnapshotDiff.compute(baseline: self, current: current)
    }
}

// MARK: - Persistence

extension TopologySnapshot {
    private static var storeURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("topology_baseline.json")
    }

    static func loadBaseline() -> TopologySnapshot? {
        PersistedStore.load(TopologySnapshot.self, from: storeURL)
    }

    @MainActor
    static func saveBaseline(_ snapshot: TopologySnapshot) {
        PersistedStore.save(snapshot, to: storeURL)
    }

    static func clearBaseline() {
        try? FileManager.default.removeItem(at: storeURL)
    }
}

// MARK: - Diff

struct SnapshotDiff {
    enum ChangeKind {
        case newDevice
        case deviceRemoved
        case wentOffline
        case cameOnline
        case wentUnreachable
        case becameReachable
        case hopCountWorse(from: Int, to: Int)
        case hopCountBetter(from: Int, to: Int)
        case signalDegraded(from: Int, to: Int)

        var isRegression: Bool {
            switch self {
            case .wentOffline, .deviceRemoved, .wentUnreachable,
                 .hopCountWorse, .signalDegraded: return true
            default: return false
            }
        }

        var icon: String {
            switch self {
            case .newDevice:         return "plus.circle"
            case .deviceRemoved:     return "minus.circle.fill"
            case .wentOffline:       return "wifi.slash"
            case .cameOnline:        return "wifi"
            case .wentUnreachable:   return "network.slash"
            case .becameReachable:   return "checkmark.circle"
            case .hopCountWorse:     return "arrow.up.circle.fill"
            case .hopCountBetter:    return "arrow.down.circle.fill"
            case .signalDegraded:    return "chart.line.downtrend.xyaxis"
            }
        }

        var label: LocalizedStringResource {
            switch self {
            case .newDevice:                      return "New device"
            case .deviceRemoved:                  return "No longer seen"
            case .wentOffline:                    return "Went offline"
            case .cameOnline:                     return "Back online"
            case .wentUnreachable:                return "Lost mesh path"
            case .becameReachable:                return "Path restored"
            case .hopCountWorse(let f, let t):    return "\(f) → \(t) hops"
            case .hopCountBetter(let f, let t):   return "\(f) → \(t) hops"
            case .signalDegraded(let f, let t):   return "\(f) → \(t) dBm"
            }
        }
    }

    struct Change: Identifiable {
        let id = UUID()
        let name: String
        let room: String?
        let kind: ChangeKind

        var sortKey: Int {
            switch kind {
            case .wentOffline, .wentUnreachable, .deviceRemoved: return 0
            case .hopCountWorse, .signalDegraded:                 return 1
            case .hopCountBetter, .becameReachable, .cameOnline:  return 2
            case .newDevice:                                       return 3
            }
        }
    }

    let changes: [Change]
    let baselineAt: Date

    var regressions: [Change] { changes.filter { $0.kind.isRegression } }
    var improvements: [Change] { changes.filter { !$0.kind.isRegression } }
    var hasChanges: Bool { !changes.isEmpty }

    static func compute(baseline: TopologySnapshot, current: TopologySnapshot) -> SnapshotDiff {
        var changes: [Change] = []
        let baseByID = Dictionary(uniqueKeysWithValues: baseline.deviceStates.map { ($0.deviceID, $0) })
        let curByID  = Dictionary(uniqueKeysWithValues: current.deviceStates.map  { ($0.deviceID, $0) })

        for (id, state) in baseByID where curByID[id] == nil {
            changes.append(Change(name: state.name, room: state.room, kind: .deviceRemoved))
        }
        for (id, state) in curByID where baseByID[id] == nil {
            changes.append(Change(name: state.name, room: state.room, kind: .newDevice))
        }

        for (id, cur) in curByID {
            guard let base = baseByID[id] else { continue }

            if !base.isOffline && cur.isOffline {
                changes.append(Change(name: cur.name, room: cur.room, kind: .wentOffline))
            } else if base.isOffline && !cur.isOffline {
                changes.append(Change(name: cur.name, room: cur.room, kind: .cameOnline))
            }

            // Unreachability is distinct from offline — device is online but has no mesh path
            if base.hopCount < 99 && cur.hopCount == 99 && !cur.isOffline {
                changes.append(Change(name: cur.name, room: cur.room, kind: .wentUnreachable))
            } else if base.hopCount == 99 && cur.hopCount < 99 {
                changes.append(Change(name: cur.name, room: cur.room, kind: .becameReachable))
            }

            // Hop count (both reachable, changed)
            if base.hopCount < 99 && cur.hopCount < 99 && base.hopCount != cur.hopCount {
                if cur.hopCount > base.hopCount {
                    changes.append(Change(name: cur.name, room: cur.room,
                                         kind: .hopCountWorse(from: base.hopCount, to: cur.hopCount)))
                } else {
                    changes.append(Change(name: cur.name, room: cur.room,
                                         kind: .hopCountBetter(from: base.hopCount, to: cur.hopCount)))
                }
            }

            // Signal degradation (10+ dBm, both online)
            if let br = base.rssi, let cr = cur.rssi, !cur.isOffline, br - cr >= 10 {
                changes.append(Change(name: cur.name, room: cur.room, kind: .signalDegraded(from: br, to: cr)))
            }
        }

        changes.sort { $0.sortKey < $1.sortKey }
        return SnapshotDiff(changes: changes, baselineAt: baseline.capturedAt)
    }
}
