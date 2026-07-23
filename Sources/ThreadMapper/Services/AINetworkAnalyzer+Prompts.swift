import Foundation

// Prompt string builders for AINetworkAnalyzer, split out of the main file.
@available(iOS 26, *)
extension AINetworkAnalyzer {

    static func buildSummaryPrompt(
        devices: [ThreadDevice],
        health: NetworkHealthScore,
        report: NetworkDiagnosticsEngine.Report?
    ) -> String {
        let total = devices.count
        let offline = devices.filter { $0.isOffline }.count
        let online = total - offline
        let borderRouters = devices.filter { $0.isBorderRouter }
        let routers = devices.filter { $0.isRoutingCapable && !$0.isBorderRouter }
        let score = health.score
        let grade = health.grade

        var parts: [String] = [
            "Thread mesh: \(total) devices (\(online) online, \(offline) offline).",
            "Border routers (hubs): \(borderRouters.count) (\(borderRouters.map(\.name).joined(separator: ", "))).",
            "Relay devices: \(routers.count).",
            "Health score: \(score)/100 (grade \(grade))."
        ]

        if let report {
            let topIssues = report.recommendations.prefix(3).map { $0.title }
            if !topIssues.isEmpty {
                parts.append("Top issues: \(topIssues.joined(separator: "; ")).")
            }
            let poorRooms = report.roomCoverage.filter { $0.gradeRank <= 1 }.map { $0.room }
            if !poorRooms.isEmpty {
                parts.append("Rooms with poor coverage: \(poorRooms.joined(separator: ", ")).")
            }
            let deepDevices = report.deviceHops.filter { $0.hopCount >= 4 && $0.hopCount < 99 }
            if !deepDevices.isEmpty {
                parts.append("Far-from-hub devices: \(deepDevices.map { "\($0.device.name) (\($0.hopCount) hops)" }.joined(separator: ", ")).")
            }
        }

        if offline > 0 {
            let offlineNames = devices.filter { $0.isOffline }.map(\.name).prefix(3)
            parts.append("Offline devices: \(offlineNames.joined(separator: ", ")).")
        }

        parts.append("Summarise the health of this Thread mesh network.\(languageInstruction)")
        return parts.joined(separator: " ")
    }

    static func buildPredictivePrompt(
        devices: [ThreadDevice],
        offlineEvents: [ActivityEvent],
        report: NetworkDiagnosticsEngine.Report?
    ) -> String {
        let frequentOffline: [UUID: Int] = offlineEvents
            .filter { $0.kind == .deviceOffline }
            .reduce(into: [:]) { dict, event in
                guard let did = event.deviceID else { return }
                dict[did, default: 0] += 1
            }

        var riskLines: [String] = []

        for device in devices where !device.isOffline {
            var risk: [String] = []
            if let count = frequentOffline[device.id], count >= 2 {
                risk.append("went offline \(count) times recently")
            }
            if let rssi = device.rssi, rssi.isWeakRSSI {
                risk.append("weak signal (\(rssi) dBm)")
            }
            if let hops = report?.deviceHops.first(where: { $0.device.id == device.id }), hops.hopCount >= 4 {
                risk.append("\(hops.hopCount) hops from hub")
            }
            if (device.batteryPercentage ?? 100) < 20 {
                risk.append("low battery (\(device.batteryPercentage!)%)")
            }
            if !risk.isEmpty {
                riskLines.append("\(device.name): \(risk.joined(separator: ", ")).")
            }
        }

        if riskLines.isEmpty {
            riskLines = ["No significant risk factors detected in the current data."]
        }

        return """
        Thread mesh device risk data:
        \(riskLines.joined(separator: "\n"))

        Based on this data, identify up to 3 devices most at risk of failure in the next 24 hours \
        and predict the overall network outlook.\(languageInstruction)
        """
    }

    static func buildOptimizationPrompt(
        devices: [ThreadDevice],
        health: NetworkHealthScore,
        anomalies: [UUID: DeviceAnomaly],
        report: NetworkDiagnosticsEngine.Report?
    ) -> String {
        var lines: [String] = [
            "Thread mesh health: \(health.score)/100 (grade \(health.grade)).",
            "Total devices: \(devices.count), offline: \(devices.filter(\.isOffline).count).",
        ]

        let anomalyLines = anomalies.values
            .filter { $0.trajectory != .stable }
            .compactMap { a -> String? in
                guard let name = devices.first(where: { $0.uniqueIdentifier == a.deviceID })?.name else { return nil }
                return "\(name): \(a.trajectory.label) (dropped \(String(format: "%.0f", a.dropDelta)) dBm)"
            }
        if !anomalyLines.isEmpty {
            lines.append("Signal anomalies: \(anomalyLines.joined(separator: "; ")).")
        }

        if let report {
            let issueText = report.recommendations.prefix(3).map(\.title).joined(separator: "; ")
            if !issueText.isEmpty { lines.append("Known issues: \(issueText).") }
        }

        let weakDevices = devices.filter { ($0.rssi ?? 0) < -75 && !$0.isOffline }
        if !weakDevices.isEmpty {
            lines.append("Weak signal: \(weakDevices.map { "\($0.name) (\($0.rssi ?? 0) dBm)" }.joined(separator: ", ")).")
        }

        lines.append("Generate a prioritised optimisation plan with up to 3 specific actions.\(languageInstruction)")
        return lines.joined(separator: " ")
    }

    static func buildRootCausePrompt(
        devices: [ThreadDevice],
        anomalies: [DeviceAnomaly],
        report: NetworkDiagnosticsEngine.Report?
    ) -> String {
        let deviceLines = anomalies.compactMap { a -> String? in
            guard let device = devices.first(where: { $0.uniqueIdentifier == a.deviceID }) else { return nil }
            let room = device.room.map { " in \($0)" } ?? ""
            return "- \(device.name)\(room): \(a.trajectory.label), dropped \(String(format: "%.0f", a.dropDelta)) dBm from baseline"
        }

        var prompt = """
        Multiple Thread devices are showing simultaneous signal degradation:
        \(deviceLines.joined(separator: "\n"))
        """

        if let report, !report.recommendations.isEmpty {
            let issueText = report.recommendations.prefix(2).map(\.title).joined(separator: "; ")
            prompt += "\nNetwork diagnostics also flagged: \(issueText)."
        }

        prompt += "\n\nIdentify the single most likely root cause for this pattern and the recommended fix.\(languageInstruction)"
        return prompt
    }

    static func buildExpansionPrompt(
        devices: [ThreadDevice],
        health: NetworkHealthScore,
        report: NetworkDiagnosticsEngine.Report?
    ) -> String {
        var lines: [String] = [
            "Thread mesh health: \(health.score)/100 (grade \(health.grade)).",
            "Total devices: \(devices.count) across \(Set(devices.compactMap(\.room)).count) rooms.",
            "Border routers: \(devices.filter(\.isBorderRouter).map(\.name).joined(separator: ", ")).",
        ]
        if let report {
            let poorRooms = report.roomCoverage.filter { $0.gradeRank <= 1 }.map(\.room)
            if !poorRooms.isEmpty {
                lines.append("Rooms with poor coverage: \(poorRooms.joined(separator: ", ")).")
            }
            let farDevices = report.deviceHops.filter { $0.hopCount >= 4 && $0.hopCount < 99 }
            if !farDevices.isEmpty {
                lines.append("Far devices (4+ hops): \(farDevices.map { "\($0.device.name) in \($0.device.room ?? "unknown room")" }.joined(separator: ", ")).")
            }
        }
        let weakRooms = devices.filter { $0.rssi?.isWeakRSSI == true && !$0.isOffline }
            .compactMap(\.room)
        let uniqueWeakRooms = Array(Set(weakRooms)).sorted()
        if !uniqueWeakRooms.isEmpty {
            lines.append("Rooms with weak signal: \(uniqueWeakRooms.joined(separator: ", ")).")
        }
        let roomsWithDevices = Set(devices.compactMap(\.room)).sorted()
        lines.append("Currently covered rooms: \(roomsWithDevices.joined(separator: ", ")).")
        lines.append("Recommend up to 2 specific locations to add Thread devices to improve this mesh.\(languageInstruction)")
        return lines.joined(separator: " ")
    }

    static func buildMaintenancePrompt(
        devices: [ThreadDevice],
        anomalies: [UUID: DeviceAnomaly],
        firmwareChanges: [FirmwareChange],
        events: [ActivityEvent]
    ) -> String {
        var lines: [String] = [
            "Thread mesh: \(devices.count) devices total, \(devices.filter(\.isOffline).count) offline."
        ]

        // Firmware age
        let staleDevices = devices.filter { d in
            guard let lastChange = firmwareChanges
                .filter({ $0.deviceID == d.uniqueIdentifier })
                .sorted(by: { $0.detectedAt > $1.detectedAt }).first
            else { return false }
            return Date().timeIntervalSince(lastChange.detectedAt) > 90 * 24 * 3600
        }
        if !staleDevices.isEmpty {
            lines.append("Devices with firmware unchanged for 90+ days: \(staleDevices.map(\.name).joined(separator: ", ")).")
        }

        // Battery-powered devices with low battery
        let lowBattery = devices.filter { ($0.batteryPercentage ?? 100) < 25 && $0.isSleepyEndDevice }
        if !lowBattery.isEmpty {
            lines.append("Low battery devices: \(lowBattery.map { "\($0.name) (\($0.batteryPercentage ?? 0)%)" }.joined(separator: ", ")).")
        }

        // Anomalies
        let declining = anomalies.values.filter { $0.trajectory != .stable }
        if !declining.isEmpty {
            let names = declining.compactMap { a in
                devices.first(where: { $0.uniqueIdentifier == a.deviceID })
                    .map { "\($0.name) (\(a.trajectory.label))" }
            }
            lines.append("Signal anomalies: \(names.joined(separator: ", ")).")
        }

        // Offline frequency
        let cutoff30d = Date().addingTimeInterval(-30 * 24 * 3600)
        let offlineCounts = events.filter { $0.kind == .deviceOffline && $0.timestamp > cutoff30d }
            .reduce(into: [UUID: Int]()) { dict, e in
                guard let did = e.deviceID else { return }
                dict[did, default: 0] += 1
            }
        let frequentlyOffline = offlineCounts.filter { $0.value >= 3 }
            .compactMap { id, count -> String? in
                devices.first(where: { $0.uniqueIdentifier == id }).map { "\($0.name) (\(count)x offline)" }
            }
        if !frequentlyOffline.isEmpty {
            lines.append("Frequently offline in 30 days: \(frequentlyOffline.joined(separator: ", ")).")
        }

        // Weak signal devices
        let weak = devices.filter { $0.rssi?.isWeakRSSI == true && !$0.isOffline }
        if !weak.isEmpty {
            lines.append("Weak signal devices: \(weak.map { "\($0.name) (\($0.rssi ?? 0) dBm)" }.joined(separator: ", ")).")
        }

        lines.append("Generate a prioritised maintenance plan with up to 6 tasks grouped by timeframe (Today / This week / This month).\(languageInstruction)")
        return lines.joined(separator: " ")
    }

    static func buildAutoHealPrompt(
        devices: [ThreadDevice],
        anomalies: [UUID: DeviceAnomaly],
        events: [ActivityEvent],
        recurringOffline: [UUID: Int],
        memoryFragments: [String]
    ) -> String {
        var lines: [String] = ["Thread mesh auto-heal analysis."]

        // Recurring offline patterns
        if !recurringOffline.isEmpty {
            let entries = recurringOffline.compactMap { id, count -> String? in
                devices.first(where: { $0.uniqueIdentifier == id })
                    .map { "\($0.name)\($0.room.map { " in \($0)" } ?? ""): offline \(count)x in 30 days" }
            }
            lines.append("Recurring offline devices: \(entries.joined(separator: "; ")).")
        }

        // Persistent anomalies
        let persistent = anomalies.values.filter { $0.trajectory != .stable }
        if !persistent.isEmpty {
            let entries = persistent.compactMap { a -> String? in
                devices.first(where: { $0.uniqueIdentifier == a.deviceID })
                    .map { "\($0.name): \(a.trajectory.label), dropped \(Int(a.dropDelta)) dBm from baseline" }
            }
            lines.append("Persistent signal issues: \(entries.joined(separator: "; ")).")
        }

        // Device memory (cross-session observations)
        if !memoryFragments.isEmpty {
            lines.append("Historical memory:")
            lines += memoryFragments.prefix(5)
        }

        lines.append("Identify root causes for recurring issues and propose specific corrective actions. Maximum 3 recommendations.\(languageInstruction)")
        return lines.joined(separator: " ")
    }

    static func buildAlertScorePrompt(
        deviceName: String,
        room: String?,
        offlineCount: Int,
        recentEvents: [ActivityEvent],
        anomaly: DeviceAnomaly?
    ) -> String {
        var lines: [String] = [
            "Alert: '\(deviceName)'\(room.map { " in \($0)" } ?? "") just went offline.",
            "Total offline devices in mesh right now: \(offlineCount).",
        ]
        if let a = anomaly, a.trajectory != .stable {
            lines.append("Signal trend before going offline: \(a.trajectory.label) (dropped \(Int(a.dropDelta)) dBm from baseline).")
        }
        let recentOfflineCount = recentEvents.filter {
            $0.kind == .deviceOffline && $0.deviceName == deviceName
            && Date().timeIntervalSince($0.timestamp) < 7 * 24 * 3600
        }.count
        if recentOfflineCount > 0 {
            lines.append("This device went offline \(recentOfflineCount) time(s) in the past 7 days.")
        }
        lines.append("Score the urgency (1–10) and decide whether to notify the user now.\(languageInstruction)")
        return lines.joined(separator: " ")
    }

    static func buildCoachingPrompt(
        devices: [ThreadDevice],
        health: NetworkHealthScore,
        history: [HealthHistoryStore.Entry]
    ) -> String {
        let weekEntries = history.filter { Date().timeIntervalSince($0.timestamp) < 7 * 24 * 3600 }
        let avgScore = weekEntries.isEmpty ? health.score
            : Int(weekEntries.map { Double($0.score) }.reduce(0, +) / Double(weekEntries.count))
        let trend: String = {
            guard weekEntries.count >= 2,
                  let first = weekEntries.first?.score, let last = weekEntries.last?.score
            else { return "steady" }
            if last - first > 5 { return "improving" }
            if first - last > 5 { return "declining" }
            return "steady"
        }()
        let offline = devices.filter(\.isOffline).count
        let weak = devices.filter { $0.rssi?.isWeakRSSI == true && !$0.isOffline }.count
        var lines: [String] = [
            "Weekly Thread mesh performance: grade \(health.grade), score \(health.score)/100.",
            "Weekly average score: \(avgScore), trend: \(trend).",
            "\(devices.count) total devices, \(offline) offline, \(weak) with weak signal.",
            "\(devices.filter(\.isBorderRouter).count) border router(s).",
        ]
        let rooms = Array(Set(devices.compactMap(\.room))).sorted()
        if !rooms.isEmpty { lines.append("Rooms: \(rooms.joined(separator: ", ")).") }
        lines.append("Generate a weekly coaching plan with 1–3 specific, achievable actions.\(languageInstruction)")
        return lines.joined(separator: " ")
    }

    static func buildAnomalyPatternPrompt(
        device: ThreadDevice,
        anomaly: DeviceAnomaly,
        recentEvents: [ActivityEvent]
    ) -> String {
        let room = device.room.map { " in \($0)" } ?? ""
        var lines: [String] = [
            "Device: '\(device.name)'\(room).",
            "Type: \(device.isBorderRouter ? "border router" : device.isRouter ? "router" : device.isSleepyEndDevice ? "battery-powered sensor" : "end device").",
            "Signal trend: \(anomaly.trajectory.label).",
            "Signal drop from baseline: \(Int(anomaly.dropDelta)) dBm.",
            "Deviation score: \(String(format: "%.2f", anomaly.deviationScore)).",
        ]
        if let rssi = device.rssi { lines.append("Current signal: \(rssi) dBm.") }
        if let hours = anomaly.projectedHoursToFailure {
            lines.append("Projected hours to critical: \(Int(hours)).")
        }
        let deviceOffline = recentEvents.filter {
            $0.deviceID == device.id && $0.kind == .deviceOffline
            && Date().timeIntervalSince($0.timestamp) < 14 * 24 * 3600
        }.count
        if deviceOffline > 0 { lines.append("Offline events in past 14 days: \(deviceOffline).") }
        lines.append("Classify this anomaly pattern with a name, evidence, and recommended fix.\(languageInstruction)")
        return lines.joined(separator: " ")
    }

    static func buildTroubleshootingPrompt(
        device: ThreadDevice,
        problem: String,
        anomaly: DeviceAnomaly?,
        recentEvents: [ActivityEvent],
        memoryFragment: String
    ) -> String {
        let room = device.room.map { " in \($0)" } ?? ""
        var lines: [String] = [
            "Device: '\(device.name)'\(room).",
            "Problem: \(problem).",
            "Type: \(device.isBorderRouter ? "border router (internet hub)" : device.isRouter ? "router (relay)" : device.isSleepyEndDevice ? "battery-powered sensor" : "end device").",
        ]
        if let rssi = device.rssi { lines.append("Current signal: \(rssi) dBm.") }
        if let a = anomaly, a.trajectory != .stable {
            lines.append("Signal trend: \(a.trajectory.label), dropped \(Int(a.dropDelta)) dBm from baseline.")
        }
        if let bat = device.batteryPercentage { lines.append("Battery: \(bat)%.") }
        let pastOffline = recentEvents.filter {
            $0.deviceID == device.id && $0.kind == .deviceOffline
            && Date().timeIntervalSince($0.timestamp) < 30 * 24 * 3600
        }.count
        if pastOffline > 0 { lines.append("Offline events in 30 days: \(pastOffline).") }
        if !memoryFragment.isEmpty { lines.append("Historical context: \(memoryFragment)") }
        lines.append("Generate 2–4 device-specific troubleshooting steps, most impactful first.\(languageInstruction)")
        return lines.joined(separator: " ")
    }

    static func buildNetworkStoryPrompt(
        devices: [ThreadDevice],
        health: NetworkHealthScore,
        history: [HealthHistoryStore.Entry],
        events: [ActivityEvent]
    ) -> String {
        let recentEntries = history.filter { Date().timeIntervalSince($0.timestamp) < 30 * 24 * 3600 }
        let avgScore = recentEntries.isEmpty ? health.score
            : Int(recentEntries.map { Double($0.score) }.reduce(0, +) / Double(recentEntries.count))
        let lowestScore = recentEntries.map(\.score).min() ?? health.score
        let highestScore = recentEntries.map(\.score).max() ?? health.score
        let recentEvents = events.filter { Date().timeIntervalSince($0.timestamp) < 30 * 24 * 3600 }
            .sorted { $0.timestamp < $1.timestamp }
        let offlineCount = recentEvents.filter { $0.kind == .deviceOffline || $0.kind == .borderRouterOffline }.count
        let topologyCount = recentEvents.filter { $0.kind == .topologyJoined || $0.kind == .topologyLeft }.count
        var lines: [String] = [
            "Thread mesh 30-day story:",
            "Current: grade \(health.grade), score \(health.score)/100.",
            "30-day: avg \(avgScore), lowest \(lowestScore), highest \(highestScore).",
            "\(devices.count) devices, \(devices.filter(\.isOffline).count) currently offline.",
            "\(offlineCount) offline events, \(topologyCount) topology changes in 30 days.",
        ]
        let keyEventSamples = recentEvents.prefix(8).map { e -> String in
            let daysAgo = Int(Date().timeIntervalSince(e.timestamp) / 86400)
            let ago = daysAgo == 0 ? "today" : "\(daysAgo)d ago"
            return "\(e.kind.label) (\(ago)): \(String(e.detail.prefix(60)))"
        }
        if !keyEventSamples.isEmpty {
            lines.append("Key events: \(keyEventSamples.joined(separator: "; ")).")
        }
        lines.append("Narrate the network's story with opening, key events, current chapter, and outlook.\(languageInstruction)")
        return lines.joined(separator: " ")
    }

    static func buildResiliencePrompt(impact: ResilienceSimulator.Impact) -> String {
        let nodeType = impact.removedNode.kind == .borderRouter ? "border router (internet hub)" : "relay device"
        let room = impact.removedNode.room.map { " in \($0)" } ?? ""
        let severityLabel: String
        switch impact.severity {
        case .critical: severityLabel = "critical"
        case .major:    severityLabel = "major"
        case .minor:    severityLabel = "minor"
        case .none:     severityLabel = "safe"
        }
        let affectedRooms = Array(Set(impact.affectedNodes.compactMap(\.room))).sorted()
        let brsRemaining = impact.isLastBorderRouter ? 0 : impact.totalBorderRouters - 1

        var lines: [String] = [
            "Scenario: removing '\(impact.removedNode.name)'\(room), a \(nodeType).",
            "Severity: \(severityLabel).",
            "End devices cut off: \(impact.affectedDeviceCount).",
            "Relay devices also lost: \(impact.affectedRouterCount).",
            "Affected rooms: \(affectedRooms.isEmpty ? "none identified" : affectedRooms.joined(separator: ", ")).",
            "Border routers remaining after removal: \(brsRemaining).",
        ]
        if impact.isLastBorderRouter {
            lines.append("This is the ONLY border router — the entire Thread network would lose internet connectivity.")
        }
        lines.append("Describe the impact in a scenario sentence and a fallback sentence.\(languageInstruction)")
        return lines.joined(separator: " ")
    }

    static func buildTopologyDigestPrompt(diff: SnapshotDiff, deviceCount: Int) -> String {
        let hoursAgo = max(1, Int(-diff.baselineAt.timeIntervalSinceNow / 3600))
        var lines: [String] = [
            "Thread mesh with \(deviceCount) total devices.",
            "Last checked \(hoursAgo) hour(s) ago. Changes since then:"
        ]
        for c in diff.changes {
            let room = c.room.map { " (\($0))" } ?? ""
            lines.append("- \(c.name)\(room): \(c.kind.promptDescription)")
        }
        let regressionCount = diff.regressions.count
        let improvementCount = diff.improvements.count
        lines.append("Regressions: \(regressionCount), improvements: \(improvementCount).")
        lines.append("Summarise what changed and whether the network is better, worse, or about the same.\(languageInstruction)")
        return lines.joined(separator: " ")
    }
}
