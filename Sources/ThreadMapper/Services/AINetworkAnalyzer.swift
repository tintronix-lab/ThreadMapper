import Foundation
import FoundationModels

// MARK: - Analyzer

@available(iOS 26, *)
struct AINetworkAnalyzer {

    // MARK: - Mesh Summary

    static func meshSummary(
        devices: [ThreadDevice],
        health: NetworkHealthScore,
        report: NetworkDiagnosticsEngine.Report?
    ) async throws -> MeshSummary {
        try await generate(
            role: """
            You are a friendly smart home expert helping a non-technical user understand \
            their Apple Thread mesh network. Be concise, warm, and specific. \
            Never use jargon like "RSSI", "BFS", "HAP", or acronyms without explanation. \
            Say "signal strength" instead of RSSI, "hub" for border router, \
            "relay device" for router. Keep responses brief.\(languageInstruction)
            """,
            prompt: buildSummaryPrompt(devices: devices, health: health, report: report),
            as: MeshSummary.self
        )
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
        try await generate(
            role: """
            You are a Thread mesh network reliability expert. \
            Predict which devices are most likely to have problems based on the data provided. \
            Be specific and actionable. Avoid jargon and acronyms.\(languageInstruction)
            """,
            prompt: buildPredictivePrompt(devices: devices, offlineEvents: offlineEvents, report: report),
            as: PredictiveAnalysis.self
        )
    }

    // MARK: - Weekly Digest Headline

    /// Generates a one-sentence plain-English weekly summary for use in the push notification body.
    static func weeklyDigestHeadline(
        devices: [ThreadDevice],
        health: NetworkHealthScore,
        historyEntries: [HealthHistoryStore.Entry]
    ) async throws -> String {
        let role = """
            You are a smart home network assistant. Write a single, friendly sentence (max 120 chars) \
            summarising how someone's Thread network performed this week. \
            Mention the grade and whether it improved, declined, or stayed steady. \
            Avoid jargon and acronyms.\(languageInstruction)
            """
        let weekEntries = historyEntries.filter {
            Date().timeIntervalSince($0.timestamp) < 7 * 24 * 3600
        }
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
        let prompt = """
        Thread mesh grade: \(health.grade), score: \(health.score)/100. \
        Weekly average score: \(avgScore). Trend: \(trend). \
        Offline devices this week: \(offline). \
        Write a one-sentence weekly summary for the home owner.
        """
        return try await generateText(role: role, prompt: prompt, limit: 120)
    }

    // MARK: - Optimization Plan (structured, typed)

    static func optimizationPlan(
        devices: [ThreadDevice],
        health: NetworkHealthScore,
        anomalies: [UUID: DeviceAnomaly],
        report: NetworkDiagnosticsEngine.Report?
    ) async throws -> OptimizationPlan {
        try await generate(
            role: """
            You are a Thread mesh network optimization expert. \
            Generate a prioritised list of concrete, actionable improvements. \
            Be specific about which device or room needs attention. Avoid jargon.\(languageInstruction)
            """,
            prompt: buildOptimizationPrompt(devices: devices, health: health, anomalies: anomalies, report: report),
            as: OptimizationPlan.self
        )
    }

    // MARK: - Root Cause Analysis

    static func rootCauseAnalysis(
        devices: [ThreadDevice],
        anomalies: [UUID: DeviceAnomaly],
        report: NetworkDiagnosticsEngine.Report?
    ) async throws -> RootCauseHypothesis? {
        let problematic = anomalies.values.filter { $0.trajectory != .stable }
        guard problematic.count >= 2 else { return nil }

        return try await generate(
            role: """
            You are a network diagnostics expert. When multiple Thread devices show the same \
            degradation pattern simultaneously, there is usually one root cause. \
            Identify the most likely single root cause and recommend a fix.\(languageInstruction)
            """,
            prompt: buildRootCausePrompt(devices: devices, anomalies: Array(problematic), report: report),
            as: RootCauseHypothesis.self
        )
    }

    // MARK: - Device Health Summary

    /// Generates a 2-sentence plain-English assessment of a single device's current health.
    static func deviceSummary(
        device: ThreadDevice,
        anomaly: DeviceAnomaly?,
        stats: DeviceStats?,
        offlineCount: Int,
        memoryFragment: String = ""
    ) async throws -> String {
        let role = """
            You are a friendly smart home expert. Write a brief, plain-English assessment of one \
            Thread device. Be specific about the device's current state. No acronyms.\(languageInstruction)
            """
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
        if !memoryFragment.isEmpty { lines.append(memoryFragment) }
        lines.append("Write 2 sentences: the device's current health state, then one specific recommendation.")
        return try await generateText(role: role, prompt: lines.joined(separator: " "), limit: 300)
    }

    // MARK: - Activity Digest

    /// Summarises recent network events in 2 plain-English sentences.
    static func activityDigest(
        events: [ActivityEvent],
        devices: [ThreadDevice]
    ) async throws -> String {
        guard !events.isEmpty else { return "" }
        let role = """
            You are a friendly network monitoring assistant. \
            Summarise recent Thread network events in 2 short, plain-English sentences. \
            No bullet points. Mention specific device names and times where helpful. \
            Maximum 200 characters total.\(languageInstruction)
            """
        let recent = events.prefix(10)
        let lines = recent.map { e -> String in
            let ago = Int(Date().timeIntervalSince(e.timestamp) / 60)
            return "\(e.kind.label): \(e.detail) (\(ago)m ago)"
        }
        let prompt = "Recent network events:\n\(lines.joined(separator: "\n"))\n\nSummarise in 2 sentences."
        return try await generateText(role: role, prompt: prompt, limit: 220)
    }

    // MARK: - Mesh Expansion Advisor

    static func meshExpansionPlan(
        devices: [ThreadDevice],
        health: NetworkHealthScore,
        report: NetworkDiagnosticsEngine.Report?
    ) async throws -> MeshExpansionPlan {
        try await generate(
            role: """
            You are a Thread mesh network expansion expert. \
            Recommend up to 2 specific places in the home to add Thread devices. \
            Be specific about rooms and explain the expected benefit. Avoid jargon.\(languageInstruction)
            """,
            prompt: buildExpansionPrompt(devices: devices, health: health, report: report),
            as: MeshExpansionPlan.self
        )
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
        let prompt = """
        Thread mesh: \(deviceCount) devices.
        User query: "\(query)"
        Parse into a structured device filter.
        """
        return try await generate(role: role, prompt: prompt, as: NLDeviceFilter.self)
    }

    // MARK: - Metric Explanation ("Explain This")

    /// Returns a 2-sentence plain-English explanation of a single metric value in context.
    static func explainMetric(
        metricName: String,
        value: String,
        context: String
    ) async throws -> String {
        let role = """
            You are a friendly smart home expert explaining one Thread network metric to a \
            non-technical user. Be warm and concise. Exactly 2 sentences. \
            No acronyms without explanation.\(languageInstruction)
            """
        let prompt = """
        Metric: \(metricName) = \(value).
        \(context)
        Explain in 2 sentences: what this value means for the smart home, and whether it is good, acceptable, or needs attention.
        """
        return try await generateText(role: role, prompt: prompt, limit: 280)
    }

    // MARK: - Commissioning Briefing (AI-B1)

    /// Generates a 3-field briefing (role, topology fit, recommendation) for a device that just joined the mesh for the first time.
    static func commissioningBriefing(
        device: ThreadDevice,
        allDevices: [ThreadDevice],
        report: NetworkDiagnosticsEngine.Report?
    ) async throws -> CommissioningBriefing {
        let role = """
            You are a friendly smart home expert welcoming a new Thread device to an existing mesh. \
            Be warm and concise. No jargon or acronyms without explanation. \
            Mention the device name in your response.\(languageInstruction)
            """
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
        return try await generate(role: role, prompt: lines.joined(separator: " "), as: CommissioningBriefing.self)
    }

    // MARK: - Maintenance Calendar (AI-B4)

    static func maintenancePlan(
        devices: [ThreadDevice],
        anomalies: [UUID: DeviceAnomaly],
        firmwareChanges: [FirmwareChange],
        events: [ActivityEvent]
    ) async throws -> MaintenancePlan {
        try await generate(
            role: """
            You are a proactive smart home maintenance expert. Generate a practical, prioritised \
            maintenance schedule for a Thread mesh network. Be specific about device names and \
            actions. No jargon. Maximum 6 tasks, ordered by priority.\(languageInstruction)
            """,
            prompt: buildMaintenancePrompt(devices: devices, anomalies: anomalies,
                                           firmwareChanges: firmwareChanges, events: events),
            as: MaintenancePlan.self
        )
    }

    // MARK: - Auto-Heal (self-healing)

    /// Returns nil when there is insufficient recurring-issue data to make healing recommendations.
    static func autoHealReport(
        devices: [ThreadDevice],
        anomalies: [UUID: DeviceAnomaly],
        events: [ActivityEvent],
        recurringOffline: [UUID: Int],
        memoryFragments: [String]
    ) async throws -> AutoHealReport? {
        let hasDeclining = anomalies.values.filter { $0.trajectory != .stable }.count >= 2
        let hasRecurring = !recurringOffline.isEmpty
        guard hasDeclining || hasRecurring else { return nil }

        return try await generate(
            role: """
            You are a self-healing network expert. Analyse recurring device failures and signal \
            degradation patterns to identify root causes and recommend corrective actions. \
            Be specific, practical, and mention device names. No jargon.\(languageInstruction)
            """,
            prompt: buildAutoHealPrompt(devices: devices, anomalies: anomalies, events: events,
                                        recurringOffline: recurringOffline, memoryFragments: memoryFragments),
            as: AutoHealReport.self
        )
    }

    // MARK: - Resilience Narration (AI-B3)

    /// Generates a plain-English story of what happens if a node is removed from the mesh.
    static func resilienceNarration(impact: ResilienceSimulator.Impact) async throws -> ResilienceNarration {
        try await generate(
            role: """
            You are a friendly smart home expert explaining a network resilience scenario to a \
            non-technical user. Be concise and specific about which rooms and devices are affected. \
            No acronyms or jargon. Mention room names and device counts.\(languageInstruction)
            """,
            prompt: buildResiliencePrompt(impact: impact),
            as: ResilienceNarration.self
        )
    }

    /// Wraps a role description with a leading language requirement when the device locale is non-English.
    /// Putting the requirement FIRST makes the model respect it for structured @Generable output.
    private static func sessionInstructions(_ role: String) -> String {
        let code = Locale.current.language.languageCode?.identifier ?? "en"
        guard code != "en" else { return role }
        let name = Locale(identifier: "en").localizedString(forLanguageCode: code) ?? code
        return "CRITICAL: Every text field you generate MUST be written in \(name), not English.\n\n\(role)"
    }

    // MARK: - Session helpers

    /// Runs one structured `@Generable` request: opens a session with the given
    /// role instructions, sends the prompt, and returns the typed content. This
    /// is the single place model requests are configured — options, retries, or
    /// logging added here apply to every feature at once.
    private static func generate<T: Generable>(
        role: String, prompt: String, as _: T.Type = T.self
    ) async throws -> T {
        let session = LanguageModelSession(instructions: sessionInstructions(role))
        return try await session.respond(to: prompt, generating: T.self).content
    }

    /// Runs one freeform text request, trimmed to `limit` characters.
    private static func generateText(role: String, prompt: String, limit: Int) async throws -> String {
        let session = LanguageModelSession(instructions: sessionInstructions(role))
        let response = try await session.respond(to: prompt)
        return String(response.content.prefix(limit))
    }

    static var languageInstruction: String {
        let code = Locale.current.language.languageCode?.identifier ?? "en"
        guard code != "en" else { return "" }
        let name = Locale(identifier: "en").localizedString(forLanguageCode: code) ?? code
        return " Respond in \(name)."
    }

    // MARK: - Alert Urgency Scoring (AI-D2)

    static func scoreOfflineAlert(
        deviceName: String,
        room: String?,
        offlineCount: Int,
        recentEvents: [ActivityEvent],
        anomaly: DeviceAnomaly?
    ) async throws -> AlertScore {
        try await generate(
            role: """
            You are a smart home network alert prioritiser. Decide whether a Thread device going \
            offline warrants an immediate push notification or is routine enough to skip. \
            Consider the device's role, recent offline history, and the current network state.\(languageInstruction)
            """,
            prompt: buildAlertScorePrompt(deviceName: deviceName, room: room,
                                          offlineCount: offlineCount, recentEvents: recentEvents,
                                          anomaly: anomaly),
            as: AlertScore.self
        )
    }

    // MARK: - Weekly Health Coach (AI-D5)

    static func networkCoach(
        devices: [ThreadDevice],
        health: NetworkHealthScore,
        history: [HealthHistoryStore.Entry]
    ) async throws -> CoachingPlan {
        try await generate(
            role: """
            You are a friendly weekly Thread mesh network coach. Review the week's performance and \
            suggest 1–3 specific, achievable improvements. Be encouraging but realistic. \
            Focus on the highest-impact changes the user can actually make.\(languageInstruction)
            """,
            prompt: buildCoachingPrompt(devices: devices, health: health, history: history),
            as: CoachingPlan.self
        )
    }

    // MARK: - Anomaly Pattern Recognition (AI-D4)

    static func classifyAnomalyPattern(
        device: ThreadDevice,
        anomaly: DeviceAnomaly,
        recentEvents: [ActivityEvent]
    ) async throws -> AnomalyPattern {
        try await generate(
            role: """
            You are a Thread mesh network anomaly classifier. Analyse the signal degradation \
            pattern for a single device and identify the specific failure pattern it matches. \
            Name the pattern, cite the evidence, and give a concrete fix.\(languageInstruction)
            """,
            prompt: buildAnomalyPatternPrompt(device: device, anomaly: anomaly,
                                              recentEvents: recentEvents),
            as: AnomalyPattern.self
        )
    }

    // MARK: - AI Troubleshooter (AI-D7)

    static func aiTroubleshootingGuide(
        device: ThreadDevice,
        problem: String,
        anomaly: DeviceAnomaly?,
        recentEvents: [ActivityEvent],
        memoryFragment: String = ""
    ) async throws -> TroubleshootingGuide {
        try await generate(
            role: """
            You are a Thread mesh network troubleshooter. Generate device-specific, \
            step-by-step troubleshooting instructions tailored to this exact device's \
            history and current state. Be practical and specific — avoid generic advice.\(languageInstruction)
            """,
            prompt: buildTroubleshootingPrompt(device: device, problem: problem,
                                               anomaly: anomaly, recentEvents: recentEvents,
                                               memoryFragment: memoryFragment),
            as: TroubleshootingGuide.self
        )
    }

    // MARK: - Network Storyteller (AI-D10)

    static func networkStory(
        devices: [ThreadDevice],
        health: NetworkHealthScore,
        history: [HealthHistoryStore.Entry],
        events: [ActivityEvent]
    ) async throws -> NetworkNarrative {
        try await generate(
            role: """
            You are a creative but factual network narrator. Tell the story of this Thread mesh \
            network over the past 30 days using the data provided. Make it engaging for a \
            non-technical smart home owner. Mention specific devices and events. \
            Keep it concise — under 200 words total.\(languageInstruction)
            """,
            prompt: buildNetworkStoryPrompt(devices: devices, health: health,
                                            history: history, events: events),
            as: NetworkNarrative.self
        )
    }
}
