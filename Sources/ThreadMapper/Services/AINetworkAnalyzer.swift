import Foundation
import FoundationModels

// MARK: - Generable output types

@available(iOS 26, *)
@Generable(description: "Plain-English health summary of a Thread mesh network")
struct MeshSummary {
    @Guide(description: "One-line status, e.g. 'Your mesh is healthy with one minor issue to address'")
    var headline: String

    @Guide(description: "2-3 sentences explaining the current state in plain English for a non-technical smart home user. Mention specific devices or rooms if relevant.")
    var explanation: String

    @Guide(description: "The single most impactful action the user should take right now, as a short instruction")
    var topAction: String
}

@available(iOS 26, *)
@Generable(description: "Risk prediction for one Thread device")
struct DeviceRiskAlert {
    @Guide(description: "The device name exactly as provided")
    var deviceName: String

    @Guide(description: "Risk level: high, medium, or low")
    var riskLevel: String

    @Guide(description: "One sentence explaining why this device may have issues soon")
    var prediction: String

    @Guide(description: "One sentence: the recommended preventive action")
    var action: String
}

@available(iOS 26, *)
@Generable(description: "Predictive network analysis covering at-risk devices")
struct PredictiveAnalysis {
    @Guide(description: "List of at-risk devices, maximum 3", .maximumCount(3))
    var alerts: [DeviceRiskAlert]

    @Guide(description: "One-sentence network stability outlook for the next 24 hours")
    var outlook: String
}

@available(iOS 26, *)
@Generable(description: "A specific, typed network improvement action the user can take")
struct ActionableInsight {
    @Guide(description: "Short title, 4–6 words maximum")
    var title: String

    @Guide(description: "One sentence describing the problem causing this recommendation")
    var problem: String

    @Guide(description: "The exact action to take, starting with a verb")
    var action: String

    @Guide(description: "Impact level: high, medium, or low")
    var impact: String

    @Guide(description: "Estimated improvement in mesh health score percentage, 0–30")
    var estimatedImprovementPercent: Int
}

@available(iOS 26, *)
@Generable(description: "A prioritised plan of network optimisation actions")
struct OptimizationPlan {
    @Guide(description: "Top improvement actions, highest impact first, maximum 3", .maximumCount(3))
    var insights: [ActionableInsight]

    @Guide(description: "Overall network health outlook after all actions, one sentence")
    var outlook: String
}

@available(iOS 26, *)
@Generable(description: "A specific location in the home where adding a Thread device would improve the mesh")
struct ExpansionSpot {
    @Guide(description: "Room or area name (e.g. 'Garage', 'Master Bedroom', 'Back Garden')")
    var location: String

    @Guide(description: "The type of device to add: 'Thread border router', 'Thread router', or 'mains-powered Thread device'")
    var deviceType: String

    @Guide(description: "One sentence explaining why this location needs improvement")
    var reason: String

    @Guide(description: "One sentence describing the expected improvement after adding a device here")
    var expectedBenefit: String
}

@available(iOS 26, *)
@Generable(description: "A mesh expansion plan recommending where to add Thread devices")
struct MeshExpansionPlan {
    @Guide(description: "Specific locations to add devices, highest priority first, maximum 2", .maximumCount(2))
    var spots: [ExpansionSpot]

    @Guide(description: "One sentence describing the overall benefit of following this plan")
    var summary: String
}

@available(iOS 26, *)
@Generable(description: "Root cause analysis when multiple devices share the same issue")
struct RootCauseHypothesis {
    @Guide(description: "The single root cause explaining all the listed symptoms, plain English")
    var rootCause: String

    @Guide(description: "Names of devices affected by this root cause")
    var affectedDevices: [String]

    @Guide(description: "Confidence in this hypothesis: high, medium, or low")
    var confidence: String

    @Guide(description: "The recommended fix, starting with a verb")
    var recommendedFix: String

    @Guide(description: "True if this issue affects the whole network rather than individual devices")
    var isNetworkWide: Bool
}

// MARK: - Analyzer

@available(iOS 26, *)
struct AINetworkAnalyzer {

    // MARK: - Mesh Summary

    static func meshSummary(
        devices: [ThreadDevice],
        health: NetworkHealthScore,
        report: NetworkDiagnosticsEngine.Report?
    ) async throws -> MeshSummary {
        let session = LanguageModelSession(
            instructions: """
            You are a friendly smart home expert helping a non-technical user understand \
            their Apple Thread mesh network. Be concise, warm, and specific. \
            Never use jargon like "RSSI", "BFS", "HAP", or acronyms without explanation. \
            Say "signal strength" instead of RSSI, "hub" for border router, \
            "relay device" for router. Keep responses brief.
            """
        )
        let response = try await session.respond(
            to: buildSummaryPrompt(devices: devices, health: health, report: report),
            generating: MeshSummary.self
        )
        return response.content
    }

    /// Exposed for the view's optional fallback path.
    static func summaryPrompt(
        devices: [ThreadDevice],
        health: NetworkHealthScore,
        report: NetworkDiagnosticsEngine.Report?
    ) -> String {
        buildSummaryPrompt(devices: devices, health: health, report: report)
    }

    // MARK: - Predictive Analysis (non-streaming — structured output)

    static func predictiveAnalysis(
        devices: [ThreadDevice],
        offlineEvents: [ActivityEvent],
        report: NetworkDiagnosticsEngine.Report?
    ) async throws -> PredictiveAnalysis {
        let session = LanguageModelSession(
            instructions: """
            You are a Thread mesh network reliability expert. \
            Predict which devices are most likely to have problems based on the data provided. \
            Be specific and actionable. Use plain English, no acronyms.
            """
        )
        let prompt = buildPredictivePrompt(devices: devices, offlineEvents: offlineEvents, report: report)
        let response = try await session.respond(to: prompt, generating: PredictiveAnalysis.self)
        return response.content
    }

    // MARK: - Weekly Digest Headline

    /// Generates a one-sentence plain-English weekly summary for use in the push notification body.
    static func weeklyDigestHeadline(
        devices: [ThreadDevice],
        health: NetworkHealthScore,
        historyEntries: [HealthHistoryStore.Entry]
    ) async throws -> String {
        let session = LanguageModelSession(
            instructions: """
            You are a smart home network assistant. Write a single, friendly sentence (max 120 chars) \
            summarising how someone's Thread network performed this week. \
            Mention the grade and whether it improved, declined, or stayed steady. \
            Plain English only, no acronyms.
            """
        )
        let weekEntries = historyEntries.filter {
            Date().timeIntervalSince($0.timestamp) < 7 * 24 * 3600
        }
        let avgScore = weekEntries.isEmpty ? health.score
            : Int(weekEntries.map { Double($0.score) }.reduce(0, +) / Double(weekEntries.count))
        let trend: String = {
            guard weekEntries.count >= 2 else { return "steady" }
            let first = weekEntries.first!.score, last = weekEntries.last!.score
            if last - first > 5 { return "improving" }
            if first - last > 5 { return "declining" }
            return "steady"
        }()
        let offline = devices.filter(\.isOffline).count
        let prompt = """
        Thread mesh grade: \(health.grade), score: \(health.score)/100. \
        Weekly average score: \(avgScore). Trend: \(trend). \
        Offline devices this week: \(offline). \
        Write a one-sentence weekly summary for the home owner.
        """
        let response = try await session.respond(to: prompt)
        return String(response.content.prefix(120))
    }

    // MARK: - Optimization Plan (structured, typed)

    static func optimizationPlan(
        devices: [ThreadDevice],
        health: NetworkHealthScore,
        anomalies: [UUID: DeviceAnomaly],
        report: NetworkDiagnosticsEngine.Report?
    ) async throws -> OptimizationPlan {
        let session = LanguageModelSession(
            instructions: """
            You are a Thread mesh network optimization expert. \
            Generate a prioritised list of concrete, actionable improvements. \
            Be specific about which device or room needs attention. Use plain English.
            """
        )
        let prompt = buildOptimizationPrompt(devices: devices, health: health, anomalies: anomalies, report: report)
        let response = try await session.respond(to: prompt, generating: OptimizationPlan.self)
        return response.content
    }

    // MARK: - Root Cause Analysis

    static func rootCauseAnalysis(
        devices: [ThreadDevice],
        anomalies: [UUID: DeviceAnomaly],
        report: NetworkDiagnosticsEngine.Report?
    ) async throws -> RootCauseHypothesis? {
        let problematic = anomalies.values.filter { $0.trajectory != .stable }
        guard problematic.count >= 2 else { return nil }

        let session = LanguageModelSession(
            instructions: """
            You are a network diagnostics expert. When multiple Thread devices show the same \
            degradation pattern simultaneously, there is usually one root cause. \
            Identify the most likely single root cause and recommend a fix.
            """
        )
        let prompt = buildRootCausePrompt(devices: devices, anomalies: Array(problematic), report: report)
        let response = try await session.respond(to: prompt, generating: RootCauseHypothesis.self)
        return response.content
    }

    // MARK: - Device Health Summary

    /// Generates a 2-sentence plain-English assessment of a single device's current health.
    static func deviceSummary(
        device: ThreadDevice,
        anomaly: DeviceAnomaly?,
        stats: DeviceStats?,
        offlineCount: Int
    ) async throws -> String {
        let session = LanguageModelSession(
            instructions: """
            You are a friendly smart home expert. Write a brief, plain-English assessment of one \
            Thread device. Be specific about the device's current state. No acronyms.
            """
        )
        var lines: [String] = [
            "Device: \(device.name)\(device.room.map { " in \($0)" } ?? "").",
            "Type: \(device.isBorderRouter ? "border router (hub)" : device.isRouter ? "router (relay)" : device.isSleepyEndDevice ? "battery-powered end device" : "end device").",
        ]
        if let rssi = device.rssi { lines.append("Current signal: \(rssi) dBm.") }
        if let avg = stats?.avgRSSI { lines.append("30-day average signal: \(avg) dBm.") }
        if let a = anomaly, a.trajectory != .stable {
            lines.append("Signal trend: \(a.trajectory.label) (dropped \(String(format: "%.0f", a.dropDelta)) dBm from baseline).")
        }
        if let bat = device.batteryPercentage { lines.append("Battery: \(bat)%.") }
        lines.append("Offline events in 30 days: \(offlineCount).")
        lines.append("Write 2 sentences: the device's current health state, then one specific recommendation.")
        let response = try await session.respond(to: lines.joined(separator: " "))
        return String(response.content.prefix(300))
    }

    // MARK: - Activity Digest

    /// Summarises recent network events in 2 plain-English sentences.
    static func activityDigest(
        events: [ActivityEvent],
        devices: [ThreadDevice]
    ) async throws -> String {
        guard !events.isEmpty else { return "" }
        let session = LanguageModelSession(
            instructions: """
            You are a friendly network monitoring assistant. \
            Summarise recent Thread network events in 2 short, plain-English sentences. \
            No bullet points. Mention specific device names and times where helpful. \
            Maximum 200 characters total.
            """
        )
        let recent = events.prefix(10)
        let lines = recent.map { e -> String in
            let ago = Int(Date().timeIntervalSince(e.timestamp) / 60)
            return "\(e.kind.label): \(e.detail) (\(ago)m ago)"
        }
        let prompt = "Recent network events:\n\(lines.joined(separator: "\n"))\n\nSummarise in 2 sentences."
        let response = try await session.respond(to: prompt)
        return String(response.content.prefix(220))
    }

    // MARK: - Mesh Expansion Advisor

    static func meshExpansionPlan(
        devices: [ThreadDevice],
        health: NetworkHealthScore,
        report: NetworkDiagnosticsEngine.Report?
    ) async throws -> MeshExpansionPlan {
        let session = LanguageModelSession(
            instructions: """
            You are a Thread mesh network expansion expert. \
            Recommend up to 2 specific places in the home to add Thread devices. \
            Be specific about rooms and explain the expected benefit. Plain English only.
            """
        )
        let prompt = buildExpansionPrompt(devices: devices, health: health, report: report)
        let response = try await session.respond(to: prompt, generating: MeshExpansionPlan.self)
        return response.content
    }

    // MARK: - Prompt builders

    private static func buildSummaryPrompt(
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

        parts.append("Summarise the health of this Thread mesh network in plain English.")
        return parts.joined(separator: " ")
    }

    private static func buildPredictivePrompt(
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
        and predict the overall network outlook.
        """
    }

    private static func buildOptimizationPrompt(
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

        lines.append("Generate a prioritised optimisation plan with up to 3 specific actions.")
        return lines.joined(separator: " ")
    }

    private static func buildRootCausePrompt(
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

        prompt += "\n\nIdentify the single most likely root cause for this pattern and the recommended fix."
        return prompt
    }

    private static func buildExpansionPrompt(
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
        lines.append("Recommend up to 2 specific locations to add Thread devices to improve this mesh.")
        return lines.joined(separator: " ")
    }
}
