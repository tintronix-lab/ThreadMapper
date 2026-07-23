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
@Generable(description: "Structured filter parsed from a natural language query about Thread mesh devices")
struct NLDeviceFilter {
    @Guide(description: "Room name to filter by. Use a lowercase substring that matches the room name (e.g. 'bedroom' matches 'Master Bedroom'). Null if no room filter.")
    var roomContains: String?

    @Guide(description: "Device role filter: 'border_router' for internet hubs, 'router' for relay devices, 'end_device' for sensors and lights. Null for no role filter.")
    var roleFilter: String?

    @Guide(description: "Status filter: 'offline' for unreachable devices, 'online' for reachable, 'weak' for poor signal. Null for no status filter.")
    var statusFilter: String?

    @Guide(description: "Minimum hop count inclusive. For '>3 hops' set 4; for '3+ hops' set 3. Null for no hop filter.")
    var minHops: Int?

    @Guide(description: "Sort order after filtering: 'rssi_weakest' (weakest signal first), 'rssi_best' (strongest first), 'hops_most' (furthest first). Null for default order.")
    var sortOrder: String?

    @Guide(description: "True to show only battery-powered (sleepy end) devices. Null for no battery filter.")
    var batteryPoweredOnly: Bool?

    @Guide(description: "One short sentence describing what this filter shows. Example: 'Bedroom devices with 3+ hops'.")
    var filterDescription: String
}

@available(iOS 26, *)
@Generable(description: "Plain-English story of a Thread mesh resilience simulation")
struct ResilienceNarration {
    @Guide(description: "1–2 sentences describing which rooms and devices lose connectivity if this node is removed, and why it matters. Mention room names. No jargon.")
    var scenario: String

    @Guide(description: "1 sentence on what coverage or fallback path remains. If no border router remains, say the whole network loses internet.")
    var fallback: String
}

@available(iOS 26, *)
@Generable(description: "AI commissioning briefing for a newly joined Thread device")
struct CommissioningBriefing {
    @Guide(description: "One sentence explaining this device's role in plain English, e.g. 'This is an internet hub that anchors your Thread network.'")
    var roleExplanation: String

    @Guide(description: "One sentence on how this device fits the current mesh, mentioning a specific benefit if applicable.")
    var topologyFit: String

    @Guide(description: "One short recommended action to get the best from this device, starting with a verb.")
    var recommendation: String
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
            instructions: sessionInstructions("""
            You are a friendly smart home expert helping a non-technical user understand \
            their Apple Thread mesh network. Be concise, warm, and specific. \
            Never use jargon like "RSSI", "BFS", "HAP", or acronyms without explanation. \
            Say "signal strength" instead of RSSI, "hub" for border router, \
            "relay device" for router. Keep responses brief.\(languageInstruction)
            """)
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
            instructions: sessionInstructions("""
            You are a Thread mesh network reliability expert. \
            Predict which devices are most likely to have problems based on the data provided. \
            Be specific and actionable. Avoid jargon and acronyms.\(languageInstruction)
            """)
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
            instructions: sessionInstructions("""
            You are a smart home network assistant. Write a single, friendly sentence (max 120 chars) \
            summarising how someone's Thread network performed this week. \
            Mention the grade and whether it improved, declined, or stayed steady. \
            Avoid jargon and acronyms.\(languageInstruction)
            """)
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
            instructions: sessionInstructions("""
            You are a Thread mesh network optimization expert. \
            Generate a prioritised list of concrete, actionable improvements. \
            Be specific about which device or room needs attention. Avoid jargon.\(languageInstruction)
            """)
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
            instructions: sessionInstructions("""
            You are a network diagnostics expert. When multiple Thread devices show the same \
            degradation pattern simultaneously, there is usually one root cause. \
            Identify the most likely single root cause and recommend a fix.\(languageInstruction)
            """)
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
            instructions: sessionInstructions("""
            You are a friendly smart home expert. Write a brief, plain-English assessment of one \
            Thread device. Be specific about the device's current state. No acronyms.\(languageInstruction)
            """)
        )
        var lines: [String] = [
            "Device: \(device.name)\(device.room.map { " in \($0)" } ?? "").",
            "Type: \(device.isBorderRouter ? "border router (hub)" : device.isRouter ? "router (relay)" : device.isSleepyEndDevice ? "battery-powered end device" : "end device").",
        ]
        if let rssi = device.rssi { lines.append("Current signal: \(rssi) dBm.") }
        if let avg = stats?.avgRSSI { lines.append("30-day average signal: \(avg) dBm.") }
        if let a = anomaly, a.trajectory != .stable {
            lines.append("Signal trend: \(a.trajectory.label) (dropped \(String(format: "%.0f", a.dropDelta)) dBm from baseline).")
            if let hours = a.projectedHoursToFailure {
                let days = hours / 24
                let estimate = days < 1
                    ? "less than 24 hours"
                    : days < 2 ? "about 1 day" : "about \(Int(days.rounded())) days"
                lines.append("At the current rate of decline, signal is projected to reach a critical level in \(estimate).")
            }
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
            instructions: sessionInstructions("""
            You are a friendly network monitoring assistant. \
            Summarise recent Thread network events in 2 short, plain-English sentences. \
            No bullet points. Mention specific device names and times where helpful. \
            Maximum 200 characters total.\(languageInstruction)
            """)
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
            instructions: sessionInstructions("""
            You are a Thread mesh network expansion expert. \
            Recommend up to 2 specific places in the home to add Thread devices. \
            Be specific about rooms and explain the expected benefit. Avoid jargon.\(languageInstruction)
            """)
        )
        let prompt = buildExpansionPrompt(devices: devices, health: health, report: report)
        let response = try await session.respond(to: prompt, generating: MeshExpansionPlan.self)
        return response.content
    }

    // MARK: - NL Device Filter

    /// Parses a natural-language query into a structured `NLDeviceFilter`.
    static func parseNLFilter(
        query: String,
        rooms: [String],
        deviceCount: Int
    ) async throws -> NLDeviceFilter {
        let role = """
        You parse natural language queries about a Thread smart home mesh network \
        into structured device filters. Be precise and literal. \
        Available rooms: \(rooms.isEmpty ? "none" : rooms.joined(separator: ", ")). \
        Match rooms case-insensitively; allow partial matches.\(languageInstruction)
        """
        let session = LanguageModelSession(instructions: sessionInstructions(role))
        let prompt = """
        Thread mesh: \(deviceCount) devices.
        User query: "\(query)"
        Parse into a structured device filter.
        """
        let response = try await session.respond(to: prompt, generating: NLDeviceFilter.self)
        return response.content
    }

    // MARK: - Metric Explanation ("Explain This")

    /// Returns a 2-sentence plain-English explanation of a single metric value in context.
    static func explainMetric(
        metricName: String,
        value: String,
        context: String
    ) async throws -> String {
        let session = LanguageModelSession(
            instructions: sessionInstructions("""
            You are a friendly smart home expert explaining one Thread network metric to a \
            non-technical user. Be warm and concise. Exactly 2 sentences. \
            No acronyms without explanation.\(languageInstruction)
            """)
        )
        let prompt = """
        Metric: \(metricName) = \(value).
        \(context)
        Explain in 2 sentences: what this value means for the smart home, and whether it is good, acceptable, or needs attention.
        """
        let response = try await session.respond(to: prompt)
        return String(response.content.prefix(280))
    }

    // MARK: - Commissioning Briefing (AI-B1)

    /// Generates a 3-field briefing (role, topology fit, recommendation) for a device that just joined the mesh for the first time.
    static func commissioningBriefing(
        device: ThreadDevice,
        allDevices: [ThreadDevice],
        report: NetworkDiagnosticsEngine.Report?
    ) async throws -> CommissioningBriefing {
        let session = LanguageModelSession(
            instructions: sessionInstructions("""
            You are a friendly smart home expert welcoming a new Thread device to an existing mesh. \
            Be warm and concise. No jargon or acronyms without explanation. \
            Mention the device name in your response.\(languageInstruction)
            """)
        )
        let roleLabel = device.isBorderRouter
            ? "border router (internet hub)"
            : device.isRouter ? "router (relay device)"
            : device.isSleepyEndDevice ? "battery-powered sensor"
            : "end device (sensor or light)"
        let hubNames = allDevices.filter(\.isBorderRouter).map(\.name)
        var lines: [String] = [
            "New device: \(device.name)\(device.room.map { " in \($0)" } ?? "").",
            "Role: \(roleLabel).",
            "Network: \(allDevices.count) devices total, \(hubNames.count) hub(s): \(hubNames.joined(separator: ", ")).",
        ]
        if let rssi = device.rssi { lines.append("Signal: \(rssi) dBm.") }
        if let report {
            let poorRooms = report.roomCoverage.filter { $0.gradeRank <= 1 }.map(\.room)
            if !poorRooms.isEmpty {
                lines.append("Rooms with poor coverage before join: \(poorRooms.joined(separator: ", ")).")
            }
            if let hops = report.deviceHops.first(where: { $0.device.id == device.id }), hops.hopCount < 99 {
                lines.append("Hop count from hub: \(hops.hopCount).")
            }
        }
        lines.append("Generate a commissioning briefing for this device.\(languageInstruction)")
        let response = try await session.respond(
            to: lines.joined(separator: " "),
            generating: CommissioningBriefing.self
        )
        return response.content
    }

    // MARK: - Resilience Narration (AI-B3)

    /// Generates a plain-English story of what happens if a node is removed from the mesh.
    static func resilienceNarration(impact: ResilienceSimulator.Impact) async throws -> ResilienceNarration {
        let session = LanguageModelSession(
            instructions: sessionInstructions("""
            You are a friendly smart home expert explaining a network resilience scenario to a \
            non-technical user. Be concise and specific about which rooms and devices are affected. \
            No acronyms or jargon. Mention room names and device counts.\(languageInstruction)
            """)
        )
        let response = try await session.respond(
            to: buildResiliencePrompt(impact: impact),
            generating: ResilienceNarration.self
        )
        return response.content
    }

    /// Wraps a role description with a leading language requirement when the device locale is non-English.
    /// Putting the requirement FIRST makes the model respect it for structured @Generable output.
    private static func sessionInstructions(_ role: String) -> String {
        let code = Locale.current.language.languageCode?.identifier ?? "en"
        guard code != "en" else { return role }
        let name = Locale(identifier: "en").localizedString(forLanguageCode: code) ?? code
        return "CRITICAL: Every text field you generate MUST be written in \(name), not English.\n\n\(role)"
    }

    private static var languageInstruction: String {
        let code = Locale.current.language.languageCode?.identifier ?? "en"
        guard code != "en" else { return "" }
        let name = Locale(identifier: "en").localizedString(forLanguageCode: code) ?? code
        return " Respond in \(name)."
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

        parts.append("Summarise the health of this Thread mesh network.\(languageInstruction)")
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
        and predict the overall network outlook.\(languageInstruction)
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

        lines.append("Generate a prioritised optimisation plan with up to 3 specific actions.\(languageInstruction)")
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

        prompt += "\n\nIdentify the single most likely root cause for this pattern and the recommended fix.\(languageInstruction)"
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
        lines.append("Recommend up to 2 specific locations to add Thread devices to improve this mesh.\(languageInstruction)")
        return lines.joined(separator: " ")
    }

    private static func buildResiliencePrompt(impact: ResilienceSimulator.Impact) -> String {
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
}
