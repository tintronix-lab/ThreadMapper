import SwiftUI

/// Pure analysis engine that produces a diagnostic report from a device list.
/// All work is synchronous and allocation-light; safe to call on any thread.
struct NetworkDiagnosticsEngine {

    // MARK: - Output types

    struct Recommendation: Identifiable {
        enum Priority: Int, Comparable {
            case critical = 0, high = 1, medium = 2
            static func < (a: Priority, b: Priority) -> Bool { a.rawValue < b.rawValue }

            var label: String {
                switch self { case .critical: "Critical"; case .high: "High"; case .medium: "Medium" }
            }
            var color: Color {
                switch self { case .critical: .red; case .high: .orange; case .medium: .yellow }
            }
        }

        enum Category { case redundancy, coverage, interference, performance }

        let id = UUID()
        let priority: Priority
        let category: Category
        let title: String
        let detail: String
        let icon: String
        var fixSteps: [String] = []
    }

    struct RoomCoverage: Identifiable {
        let id = UUID()
        let room: String
        let totalDevices: Int
        let onlineDevices: Int
        let avgRSSI: Int?
        let grade: String
        let gradeColor: Color
        let hasRouter: Bool
        let routerNames: [String]

        // Grade rank: A=4 best, F=0 worst — used for sorting
        var gradeRank: Int {
            switch grade { case "A": 4; case "B": 3; case "C": 2; case "D": 1; default: 0 }
        }
    }

    struct DeviceHopInfo: Identifiable {
        let id = UUID()
        let device: ThreadDevice
        let hopCount: Int      // 1 = border router, 99 = unreachable
        let parentName: String?
    }

    // Routing device whose removal would isolate downstream end devices
    struct ResilienceNode: Identifiable {
        let id = UUID()
        let device: ThreadDevice
        let isolatedCount: Int       // devices that lose connectivity if this node fails
        let isolatedNames: [String]  // first 4 names for display
    }

    // Device whose RSSI has dropped significantly in the last 30 minutes
    struct SignalTrendAlert: Identifiable {
        let id = UUID()
        let device: ThreadDevice
        let recentAvgRSSI: Int
        let baselineAvgRSSI: Int
        let degradationDB: Int  // positive = getting worse
    }

    // A cluster of devices with no path to any border router
    struct NetworkPartition: Identifiable {
        let id = UUID()
        let devices: [ThreadDevice]
        let gatewayDevice: ThreadDevice?  // the reachable device this cluster should route through
    }

    struct ChannelStats: Identifiable {
        enum InterferenceRisk {
            case high    // directly overlaps a common Wi-Fi non-overlapping channel (1, 6, 11)
            case medium  // near a common Wi-Fi channel
            case low     // in a cleaner part of the 2.4 GHz band

            var label: String {
                switch self { case .high: "High"; case .medium: "Medium"; case .low: "Low" }
            }
            var color: Color {
                switch self { case .high: .red; case .medium: .orange; case .low: .green }
            }
            var icon: String {
                switch self { case .high: "exclamationmark.triangle.fill"; case .medium: "exclamationmark.circle"; case .low: "checkmark.circle.fill" }
            }
        }

        let id = UUID()
        let channel: Int
        let deviceCount: Int
        let deviceNames: [String]
        let interferenceRisk: InterferenceRisk
        let frequencyMHz: Int   // center frequency
    }

    struct Report {
        let recommendations: [Recommendation]
        let roomCoverage: [RoomCoverage]         // sorted worst-first
        let deviceHops: [DeviceHopInfo]           // sorted deepest-first
        let singlePointsOfFailure: [ThreadDevice]
        let channelStats: [ChannelStats]          // sorted by channel number
        let resilienceNodes: [ResilienceNode]     // sorted by isolatedCount desc, top 5
        let signalTrendAlerts: [SignalTrendAlert] // sorted by degradationDB desc
        let partitions: [NetworkPartition]        // isolated device clusters, largest first
        let totalBorderRouters: Int
        let totalRouters: Int
        let meshLinks: [MeshLink]
        let meshNodes: [MeshNode]
    }

    // MARK: - Analysis

    // trendsByDeviceID: keyed by ThreadDevice.uniqueIdentifier → RSSI readings oldest-first
    static func analyze(devices: [ThreadDevice], trendsByDeviceID: [UUID: [Int]] = [:]) -> Report {
        guard !devices.isEmpty else {
            return Report(recommendations: [], roomCoverage: [], deviceHops: [],
                          singlePointsOfFailure: [], channelStats: [],
                          resilienceNodes: [], signalTrendAlerts: [], partitions: [],
                          totalBorderRouters: 0, totalRouters: 0,
                          meshLinks: [], meshNodes: [])
        }

        let (nodes, links) = MeshTopologyBuilder.buildGraph(from: devices)

        let nodeByID = Dictionary(uniqueKeysWithValues: nodes.map { ($0.id, $0) })
        let deviceByID = Dictionary(uniqueKeysWithValues: devices.map { ($0.id, $0) })

        // Parent → children from the parentID on each node
        var childrenOf: [UUID: [UUID]] = [:]
        for node in nodes {
            if let pid = node.parentID { childrenOf[pid, default: []].append(node.id) }
        }

        // BFS hop-count from border routers (tier 1 = 1 hop from internet)
        var hopCounts: [UUID: Int] = [:]
        var bfsQueue: [(id: UUID, hop: Int)] = nodes
            .filter { $0.kind == .borderRouter }
            .map { ($0.id, 1) }
        while !bfsQueue.isEmpty {
            let (nodeID, hop) = bfsQueue.removeFirst()
            guard hopCounts[nodeID] == nil else { continue }
            hopCounts[nodeID] = hop
            for childID in childrenOf[nodeID] ?? [] where hopCounts[childID] == nil {
                bfsQueue.append((childID, hop + 1))
            }
        }

        let borderRouters = devices.filter(\.isBorderRouter)

        // Network partition detection: find isolated device clusters with no border router path
        var networkPartitions: [NetworkPartition] = []
        if !borderRouters.isEmpty {
            let unreachableIDs = Set(nodes.filter { hopCounts[$0.id] == nil }.map { $0.id })
            if !unreachableIDs.isEmpty {
                // Partition roots: unreachable nodes whose parent is reachable (or absent)
                let partitionRoots = unreachableIDs.filter { id -> Bool in
                    guard let node = nodeByID[id], let parentID = node.parentID else { return true }
                    return !unreachableIDs.contains(parentID)
                }
                var visitedInPartition = Set<UUID>()
                for rootID in partitionRoots where !visitedInPartition.contains(rootID) {
                    var component: [ThreadDevice] = []
                    var queue: [UUID] = [rootID]
                    var seen = Set<UUID>()
                    while !queue.isEmpty {
                        let cur = queue.removeFirst()
                        guard seen.insert(cur).inserted else { continue }
                        visitedInPartition.insert(cur)
                        if let device = deviceByID[cur] { component.append(device) }
                        for childID in childrenOf[cur] ?? [] where unreachableIDs.contains(childID) {
                            queue.append(childID)
                        }
                    }
                    guard !component.isEmpty else { continue }
                    let gatewayID = nodeByID[rootID]?.parentID
                    networkPartitions.append(NetworkPartition(
                        devices: component.sorted { $0.name < $1.name },
                        gatewayDevice: gatewayID.flatMap { deviceByID[$0] }
                    ))
                }
                networkPartitions.sort { $0.devices.count > $1.devices.count }
            }
        }

        // Device hop info
        let deviceHops: [DeviceHopInfo] = devices.map { device in
            let hop = hopCounts[device.id] ?? 99
            let parentID = nodeByID[device.id]?.parentID
            let parentName = parentID.flatMap { deviceByID[$0]?.name }
            return DeviceHopInfo(device: device, hopCount: hop, parentName: parentName)
        }.sorted { $0.hopCount > $1.hopCount }

        // SPOF: non-BR router that is the sole routing node in its room AND has end-device children
        let routerDevices = devices.filter { $0.isRoutingCapable && !$0.isBorderRouter }
        let spofDevices: [ThreadDevice] = routerDevices.filter { router in
            guard let room = router.room else { return false }
            let otherRoutersInRoom = routerDevices.filter { $0.id != router.id && $0.room == room }
            guard otherRoutersInRoom.isEmpty else { return false }
            return (childrenOf[router.id] ?? []).contains { nodeByID[$0]?.kind == .endDevice }
        }

        // Room coverage
        let devicesByRoom = Dictionary(grouping: devices.filter { $0.room != nil }, by: { $0.room! })
        let roomCoverage: [RoomCoverage] = devicesByRoom.map { room, roomDevices in
            let total = roomDevices.count
            let online = roomDevices.filter { !$0.isOffline }.count
            let rssis = roomDevices.compactMap(\.rssi).filter { $0 != -100 && $0 != 0 }
            let avg: Int? = rssis.isEmpty ? nil : rssis.reduce(0, +) / rssis.count
            let roomRouters = roomDevices.filter(\.isRoutingCapable)

            let grade: String
            let color: Color
            if online == 0 {
                grade = "F"; color = .red
            } else if total > 1, Double(online) / Double(total) < 0.5 {
                grade = "D"; color = .red
            } else if let avg {
                if avg > -65 { grade = "A"; color = .green }
                else if avg > -75 { grade = "B"; color = .mint }
                else if avg > -85 { grade = "C"; color = .orange }
                else { grade = "D"; color = .red }
            } else {
                grade = "B"; color = .mint   // online but no RSSI data — assume ok
            }

            return RoomCoverage(room: room, totalDevices: total, onlineDevices: online,
                                avgRSSI: avg, grade: grade, gradeColor: color,
                                hasRouter: !roomRouters.isEmpty,
                                routerNames: roomRouters.map(\.name))
        }.sorted { $0.gradeRank < $1.gradeRank }  // worst first

        // Recommendations
        var recs: [Recommendation] = []
        let offline = devices.filter(\.isOffline)
        let weak = devices.filter(\.isWeak)

        // Border router redundancy
        if borderRouters.isEmpty {
            recs.append(.init(
                priority: .critical, category: .redundancy,
                title: "No Border Router Detected",
                detail: "Your Thread network cannot function without a border router. Add a HomePod mini, HomePod, or Apple TV 4K.",
                icon: "antenna.radiowaves.left.and.right.slash",
                fixSteps: [
                    "Add a HomePod mini, HomePod 2nd gen, or Apple TV 4K (3rd gen or later) to your home.",
                    "Open the Home app and follow the device setup wizard.",
                    "Once set up, the device automatically becomes a Thread border router.",
                    "Tap Rescan in ThreadMapper to verify detection."
                ]
            ))
        } else if borderRouters.count == 1 {
            recs.append(.init(
                priority: .high, category: .redundancy,
                title: "Single Border Router — No Failover",
                detail: "If \(borderRouters[0].name) goes offline, your entire Thread mesh loses internet connectivity. Add a second border router.",
                icon: "exclamationmark.triangle.fill",
                fixSteps: [
                    "Add a second Thread border router — HomePod mini, HomePod, or Apple TV 4K.",
                    "Place it in a different room or floor from your existing border router.",
                    "Thread will automatically configure leader election and failover.",
                    "No manual setup required — border routers coordinate automatically."
                ]
            ))
        }

        // Offline devices
        if !offline.isEmpty {
            let names = offline.prefix(3).map(\.name).joined(separator: ", ")
            let tail = offline.count > 3 ? " and \(offline.count - 3) more" : ""
            recs.append(.init(
                priority: .critical, category: .coverage,
                title: "\(offline.count) Device\(offline.count == 1 ? "" : "s") Offline",
                detail: "\(names)\(tail) cannot be reached. Check power supply and mesh reachability.",
                icon: "network.slash",
                fixSteps: [
                    "Confirm each offline device is powered on and within range of a Thread router.",
                    "Power-cycle the device: unplug it, wait 10 seconds, then plug it back in.",
                    "Verify the device's room is covered by at least one Thread router.",
                    "If the device stays offline, remove it from the Home app and re-add it."
                ]
            ))
        }

        // Rooms missing a router with multiple devices
        for room in roomCoverage where !room.hasRouter && room.totalDevices > 1 {
            recs.append(.init(
                priority: .medium, category: .coverage,
                title: "\(room.room) Has No Thread Router",
                detail: "\(room.totalDevices) devices in \(room.room) depend on a distant router. Add a mains-powered Thread device to this room.",
                icon: "house.and.flag",
                fixSteps: [
                    "Add a mains-powered Thread device (smart plug, bulb, or hub) in \(room.room).",
                    "Mains-powered Thread devices automatically act as mesh routers.",
                    "Alternatively, reposition an existing router closer to \(room.room).",
                    "Re-run diagnostics after placement to confirm coverage improves."
                ]
            ))
        }

        // Devices at 4+ hops
        let deepDevices = deviceHops.filter { $0.hopCount >= 4 && !$0.device.isOffline }
        if !deepDevices.isEmpty {
            let names = deepDevices.prefix(2).map(\.device.name).joined(separator: ", ")
            recs.append(.init(
                priority: .medium, category: .performance,
                title: "\(deepDevices.count) Device\(deepDevices.count == 1 ? "" : "s") at 4+ Hops",
                detail: "\(names) — deep hop counts increase latency and reduce mesh reliability. Add an intermediate router to shorten the path.",
                icon: "point.3.connected.trianglepath.dotted",
                fixSteps: [
                    "Review Mesh Depth below to identify which room is missing a Thread router.",
                    "Add a mains-powered Thread device in that room — it becomes a relay automatically.",
                    "Aim to keep all devices within 3 hops of a border router.",
                    "Re-run diagnostics after placement to verify hop counts improved."
                ]
            ))
        }

        // Weak signal cluster per room (≥2 weak devices in same room)
        let weakByRoom = Dictionary(grouping: weak.filter { $0.room != nil }, by: { $0.room! })
        for (room, weakDevices) in weakByRoom where weakDevices.count >= 2 {
            recs.append(.init(
                priority: .high, category: .coverage,
                title: "Weak Signal Cluster in \(room)",
                detail: "\(weakDevices.count) devices in \(room) report poor signal (< −80 dBm). Add a router or move devices closer to an existing one.",
                icon: "wifi.exclamationmark",
                fixSteps: [
                    "Add a Thread router (mains-powered device) in \(room) to serve as a local relay.",
                    "Check for physical obstructions — concrete walls and metal cabinets attenuate 2.4 GHz significantly.",
                    "Try moving the affected devices closer to an existing router.",
                    "Weak signal (< −80 dBm) increases packet loss — aim for above −75 dBm."
                ]
            ))
        }

        // Single-point routers
        if !spofDevices.isEmpty {
            let names = spofDevices.prefix(2).map(\.name).joined(separator: ", ")
            let tail = spofDevices.count > 2 ? " and \(spofDevices.count - 2) more" : ""
            recs.append(.init(
                priority: .high, category: .redundancy,
                title: "Single-Point Routers Detected",
                detail: "\(names)\(tail) are the only routers in their rooms. Add a second router per affected room to eliminate this vulnerability.",
                icon: "exclamationmark.circle.fill",
                fixSteps: [
                    "Add a second mains-powered Thread device in the same room as each flagged router.",
                    "Thread automatically distributes traffic across both routers.",
                    "If the primary fails, the backup takes over with no manual intervention.",
                    "Smart plugs and light switches are cost-effective options for Thread routing."
                ]
            ))
        }

        // Thread channel / 2.4 GHz Wi-Fi overlap
        let usedChannels = Set(devices.compactMap(\.channel))
        let wifiOverlapChannels: Set<Int> = [11, 12, 13, 14, 17, 18, 19, 22, 23, 24]
        let conflicts = usedChannels.intersection(wifiOverlapChannels)
        if !conflicts.isEmpty {
            let chList = conflicts.sorted().map { "CH\($0)" }.joined(separator: ", ")
            recs.append(.init(
                priority: .medium, category: .interference,
                title: "Thread Channel Overlaps 2.4 GHz Wi-Fi",
                detail: "\(chList) overlap with Wi-Fi. Thread channels 15, 20, or 25 avoid 2.4 GHz interference. Adjust via your border router settings.",
                icon: "waveform.badge.exclamationmark",
                fixSteps: [
                    "Open your border router management interface (OTBR Web UI or vendor app).",
                    "Change the Thread network to channel 15, 20, or 25 — these avoid Wi-Fi overlap.",
                    "Channels 11–14, 17–19, and 22–24 overlap Wi-Fi channels 1, 6, and 11 respectively.",
                    "After the change, all Thread devices rejoin automatically."
                ]
            ))
        }

        // Signal trend analysis: flag devices whose RSSI dropped ≥8 dBm in the last 30 min
        let deviceByUniqueID = Dictionary(uniqueKeysWithValues: devices.map { ($0.uniqueIdentifier, $0) })
        var signalTrendAlerts: [SignalTrendAlert] = []
        for (uniqueID, readings) in trendsByDeviceID {
            guard readings.count >= 12, let device = deviceByUniqueID[uniqueID] else { continue }
            let half = readings.count / 2
            let baselineAvg = readings.prefix(half).reduce(0, +) / half
            let recentAvg = readings.suffix(half).reduce(0, +) / (readings.count - half)
            let degradation = baselineAvg - recentAvg  // positive = signal getting worse
            if degradation >= 8 {
                signalTrendAlerts.append(SignalTrendAlert(
                    device: device,
                    recentAvgRSSI: recentAvg,
                    baselineAvgRSSI: baselineAvg,
                    degradationDB: degradation
                ))
            }
        }
        signalTrendAlerts.sort { $0.degradationDB > $1.degradationDB }

        if !signalTrendAlerts.isEmpty {
            let names = signalTrendAlerts.prefix(2).map(\.device.name).joined(separator: ", ")
            let tail = signalTrendAlerts.count > 2 ? " and \(signalTrendAlerts.count - 2) more" : ""
            recs.append(.init(
                priority: .high, category: .performance,
                title: "\(signalTrendAlerts.count) Device\(signalTrendAlerts.count == 1 ? "" : "s") Signal Degrading",
                detail: "\(names)\(tail) — signal dropped 8+ dBm in the last 30 minutes. Check for new interference or obstructions.",
                icon: "chart.line.downtrend.xyaxis",
                fixSteps: [
                    "Check if anything new (furniture, appliance) was recently placed near the affected device.",
                    "Power-cycle the device — temporary interference can cause RSSI drops.",
                    "Look for new 2.4 GHz devices or microwave activity in the affected area.",
                    "If degradation persists, add a Thread router closer to the device."
                ]
            ))
        }

        // Failure impact simulation: for each non-BR router, remove it and re-run BFS
        var resilienceNodes: [ResilienceNode] = []
        let meshRouterNodes = nodes.filter { $0.kind == .router }
        for router in meshRouterNodes {
            let routerID = router.id
            guard deviceByID[routerID] != nil else { continue }
            // Build modified children map without this router's subtree
            var modChildrenOf = childrenOf
            modChildrenOf.removeValue(forKey: routerID)
            if let pid = router.parentID { modChildrenOf[pid]?.removeAll { $0 == routerID } }

            // BFS from border routers without this node
            var reachable = Set<UUID>()
            var q = nodes.filter { $0.kind == .borderRouter }.map(\.id)
            while !q.isEmpty {
                let cur = q.removeFirst()
                guard reachable.insert(cur).inserted else { continue }
                q.append(contentsOf: modChildrenOf[cur] ?? [])
            }

            // Devices that were reachable before but are now isolated
            let isolated = devices.filter { d in
                d.id != routerID && hopCounts[d.id] != nil && !reachable.contains(d.id)
            }
            if !isolated.isEmpty {
                resilienceNodes.append(ResilienceNode(
                    device: deviceByID[routerID]!,
                    isolatedCount: isolated.count,
                    isolatedNames: isolated.prefix(4).map(\.name)
                ))
            }
        }
        resilienceNodes.sort { $0.isolatedCount > $1.isolatedCount }
        let topResilienceNodes = Array(resilienceNodes.prefix(5))

        // Network partition recommendation
        if !networkPartitions.isEmpty {
            let totalIsolated = networkPartitions.reduce(0) { $0 + $1.devices.count }
            let clusterWord = networkPartitions.count == 1 ? "cluster" : "clusters"
            recs.append(.init(
                priority: .critical, category: .redundancy,
                title: "Thread Network Fragmented — \(totalIsolated) Device\(totalIsolated == 1 ? "" : "s") Isolated",
                detail: "\(networkPartitions.count) isolated \(clusterWord) detected with no path to any border router. Affected devices are completely unreachable.",
                icon: "exclamationmark.triangle.fill",
                fixSteps: [
                    "Check if the router(s) these clusters depended on are powered off or offline.",
                    "Power-cycle the missing intermediate router and wait 60 seconds for it to rejoin.",
                    "If the router is gone permanently, add a new Thread router in the affected area.",
                    "Re-run diagnostics to confirm isolated devices have rejoined the mesh."
                ]
            ))
        }

        recs.sort { $0.priority < $1.priority }

        // Channel analysis
        // Thread 802.15.4 channel 11 starts at 2405 MHz, each channel is 5 MHz wide.
        // Wi-Fi 2.4 GHz non-overlapping channels: 1 (2412), 6 (2437), 11 (2462) ± ~11 MHz
        // Thread channels that fall within those Wi-Fi bands:
        //   Wi-Fi CH1  (2401–2423): Thread 11–13
        //   Wi-Fi CH6  (2426–2448): Thread 17–19
        //   Wi-Fi CH11 (2451–2473): Thread 22–24
        let highRiskChannels: Set<Int> = [11, 12, 13, 17, 18, 19, 22, 23, 24]
        let mediumRiskChannels: Set<Int> = [14, 16, 20, 21, 25]

        let devicesByChannel = Dictionary(grouping: devices.compactMap { d -> (Int, ThreadDevice)? in
            guard let ch = d.channel else { return nil }
            return (ch, d)
        }, by: { $0.0 })

        let channelStats: [ChannelStats] = devicesByChannel.map { ch, pairs in
            let devs = pairs.map(\.1)
            let risk: ChannelStats.InterferenceRisk
            if highRiskChannels.contains(ch) { risk = .high }
            else if mediumRiskChannels.contains(ch) { risk = .medium }
            else { risk = .low }
            let freqMHz = 2405 + (ch - 11) * 5
            return ChannelStats(channel: ch, deviceCount: devs.count,
                                deviceNames: devs.map(\.name).sorted(),
                                interferenceRisk: risk, frequencyMHz: freqMHz)
        }.sorted { $0.channel < $1.channel }

        return Report(
            recommendations: recs,
            roomCoverage: roomCoverage,
            deviceHops: deviceHops,
            singlePointsOfFailure: spofDevices,
            channelStats: channelStats,
            resilienceNodes: topResilienceNodes,
            signalTrendAlerts: signalTrendAlerts,
            partitions: networkPartitions,
            totalBorderRouters: borderRouters.count,
            totalRouters: routerDevices.count,
            meshLinks: links,
            meshNodes: nodes
        )
    }
}
