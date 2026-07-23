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
@Generable(description: "A single maintenance task for one Thread device")
struct MaintenanceTask {
    @Guide(description: "Device name exactly as provided")
    var deviceName: String

    @Guide(description: "Task category: 'firmware', 'battery', 'signal', or 'reliability'")
    var category: String

    @Guide(description: "Priority: 'critical', 'high', 'medium', or 'low'")
    var priority: String

    @Guide(description: "When to do it: 'Today', 'This week', or 'This month'")
    var timeframe: String

    @Guide(description: "The specific action to take, starting with a verb. E.g. 'Replace battery before it drops below 10%.'")
    var action: String

    @Guide(description: "One sentence explaining why this task is needed right now")
    var reason: String
}

@available(iOS 26, *)
@Generable(description: "A prioritised maintenance plan for a Thread mesh network")
struct MaintenancePlan {
    @Guide(description: "Maintenance tasks ordered by priority, maximum 6", .maximumCount(6))
    var tasks: [MaintenanceTask]

    @Guide(description: "One sentence summarising the overall maintenance outlook")
    var summary: String
}

@available(iOS 26, *)
@Generable(description: "A self-healing recommendation for a recurring device issue")
struct HealingRecommendation {
    @Guide(description: "Device name exactly as provided")
    var deviceName: String

    @Guide(description: "The recurring issue pattern observed, e.g. 'Offline 4 times in 2 weeks'")
    var issuePattern: String

    @Guide(description: "The most likely root cause in plain English, no jargon")
    var rootCause: String

    @Guide(description: "The specific corrective action, starting with a verb")
    var proposedFix: String

    @Guide(description: "Urgency: 'critical', 'high', or 'medium'")
    var urgency: String

    @Guide(description: "Confidence in this diagnosis: 'high', 'medium', or 'low'")
    var confidence: String
}

@available(iOS 26, *)
@Generable(description: "An auto-heal report identifying recurring issues and their fixes")
struct AutoHealReport {
    @Guide(description: "Devices with recurring issues, highest urgency first, maximum 3", .maximumCount(3))
    var recommendations: [HealingRecommendation]

    @Guide(description: "One sentence describing the overall pattern across affected devices")
    var networkPattern: String
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

// MARK: - AI-D2: Alert Urgency Scoring

@available(iOS 26, *)
@Generable(description: "Urgency assessment for a Thread network offline alert before sending it to the user")
struct AlertScore {
    @Guide(description: "Urgency from 1 (informational) to 10 (critical). 7+ means send immediately.")
    var urgency: Int
    @Guide(description: "One sentence of context explaining why this alert matters right now.")
    var context: String
    @Guide(description: "True if the alert should be sent immediately; false if it can be skipped.")
    var shouldNotifyNow: Bool
}

// MARK: - AI-D5: Weekly Health Coach

@available(iOS 26, *)
@Generable(description: "A single coaching action to improve Thread mesh health this week")
struct CoachingAction {
    @Guide(description: "Short action title, 4–6 words")
    var title: String
    @Guide(description: "One sentence explaining why this action is recommended right now")
    var rationale: String
    @Guide(description: "Expected grade improvement if this action is taken, e.g. 'B→A' or 'no change'")
    var expectedGradeGain: String
    @Guide(description: "Effort level: 'low', 'medium', or 'high'")
    var effort: String
}

@available(iOS 26, *)
@Generable(description: "Personalised weekly coaching plan for a Thread mesh network")
struct CoachingPlan {
    @Guide(description: "2-sentence motivating opening summarising this week's health and key theme")
    var opening: String
    @Guide(description: "Prioritised coaching actions, highest impact first, maximum 3", .maximumCount(3))
    var actions: [CoachingAction]
}

// MARK: - AI-D4: Anomaly Pattern Recognition

@available(iOS 26, *)
@Generable(description: "AI-recognised anomaly pattern for a degrading Thread device")
struct AnomalyPattern {
    @Guide(description: "Short descriptive pattern name, e.g. 'Nightly Signal Drop' or 'Gradual Hardware Fade'")
    var patternName: String
    @Guide(description: "Confidence that this is the correct pattern: 'high', 'medium', or 'low'")
    var confidence: String
    @Guide(description: "Up to 3 specific evidence points from the device data", .maximumCount(3))
    var evidencePoints: [String]
    @Guide(description: "One sentence describing what makes this pattern distinct from random noise")
    var distinguishingFeature: String
    @Guide(description: "The recommended fix for this specific pattern, starting with a verb")
    var recommendedFix: String
}

// MARK: - AI-D7: AI Troubleshooter

@available(iOS 26, *)
@Generable(description: "A single AI-generated troubleshooting step tailored to a specific device")
struct AITroubleshootingStep {
    @Guide(description: "Plain-English instruction starting with an action verb")
    var instruction: String
    @Guide(description: "Optional hint sentence. Use empty string if no hint is needed.")
    var hint: String
}

@available(iOS 26, *)
@Generable(description: "AI-generated device-specific troubleshooting guide")
struct TroubleshootingGuide {
    @Guide(description: "One sentence diagnosis of the most likely cause for this device's problem")
    var diagnosis: String
    @Guide(description: "Ordered troubleshooting steps, most impactful first, maximum 4", .maximumCount(4))
    var steps: [AITroubleshootingStep]
}

// MARK: - AI-D10: Network Storyteller

@available(iOS 26, *)
@Generable(description: "A narrative story of the Thread network's recent history")
struct NetworkNarrative {
    @Guide(description: "1–2 sentence engaging opening about the network's overall recent story")
    var opening: String
    @Guide(description: "Key events in the story, each one sentence, maximum 4", .maximumCount(4))
    var keyEvents: [String]
    @Guide(description: "One sentence describing the current chapter: what's happening right now")
    var currentChapter: String
    @Guide(description: "One sentence outlook: where the network is heading if nothing changes")
    var outlook: String
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
        offlineCount: Int,
        memoryFragment: String = ""
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
        if !memoryFragment.isEmpty { lines.append(memoryFragment) }
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

    // MARK: - Maintenance Calendar (AI-B4)

    static func maintenancePlan(
        devices: [ThreadDevice],
        anomalies: [UUID: DeviceAnomaly],
        firmwareChanges: [FirmwareChange],
        events: [ActivityEvent]
    ) async throws -> MaintenancePlan {
        let session = LanguageModelSession(
            instructions: sessionInstructions("""
            You are a proactive smart home maintenance expert. Generate a practical, prioritised \
            maintenance schedule for a Thread mesh network. Be specific about device names and \
            actions. No jargon. Maximum 6 tasks, ordered by priority.\(languageInstruction)
            """)
        )
        let prompt = buildMaintenancePrompt(devices: devices, anomalies: anomalies,
                                            firmwareChanges: firmwareChanges, events: events)
        let response = try await session.respond(to: prompt, generating: MaintenancePlan.self)
        return response.content
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

        let session = LanguageModelSession(
            instructions: sessionInstructions("""
            You are a self-healing network expert. Analyse recurring device failures and signal \
            degradation patterns to identify root causes and recommend corrective actions. \
            Be specific, practical, and mention device names. No jargon.\(languageInstruction)
            """)
        )
        let prompt = buildAutoHealPrompt(devices: devices, anomalies: anomalies, events: events,
                                         recurringOffline: recurringOffline, memoryFragments: memoryFragments)
        let response = try await session.respond(to: prompt, generating: AutoHealReport.self)
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

    // MARK: - Alert Urgency Scoring (AI-D2)

    static func scoreOfflineAlert(
        deviceName: String,
        room: String?,
        offlineCount: Int,
        recentEvents: [ActivityEvent],
        anomaly: DeviceAnomaly?
    ) async throws -> AlertScore {
        let session = LanguageModelSession(
            instructions: sessionInstructions("""
            You are a smart home network alert prioritiser. Decide whether a Thread device going \
            offline warrants an immediate push notification or is routine enough to skip. \
            Consider the device's role, recent offline history, and the current network state.\(languageInstruction)
            """)
        )
        let prompt = buildAlertScorePrompt(deviceName: deviceName, room: room,
                                           offlineCount: offlineCount, recentEvents: recentEvents,
                                           anomaly: anomaly)
        let response = try await session.respond(to: prompt, generating: AlertScore.self)
        return response.content
    }

    // MARK: - Weekly Health Coach (AI-D5)

    static func networkCoach(
        devices: [ThreadDevice],
        health: NetworkHealthScore,
        history: [HealthHistoryStore.Entry]
    ) async throws -> CoachingPlan {
        let session = LanguageModelSession(
            instructions: sessionInstructions("""
            You are a friendly weekly Thread mesh network coach. Review the week's performance and \
            suggest 1–3 specific, achievable improvements. Be encouraging but realistic. \
            Focus on the highest-impact changes the user can actually make.\(languageInstruction)
            """)
        )
        let prompt = buildCoachingPrompt(devices: devices, health: health, history: history)
        let response = try await session.respond(to: prompt, generating: CoachingPlan.self)
        return response.content
    }

    // MARK: - Anomaly Pattern Recognition (AI-D4)

    static func classifyAnomalyPattern(
        device: ThreadDevice,
        anomaly: DeviceAnomaly,
        recentEvents: [ActivityEvent]
    ) async throws -> AnomalyPattern {
        let session = LanguageModelSession(
            instructions: sessionInstructions("""
            You are a Thread mesh network anomaly classifier. Analyse the signal degradation \
            pattern for a single device and identify the specific failure pattern it matches. \
            Name the pattern, cite the evidence, and give a concrete fix.\(languageInstruction)
            """)
        )
        let prompt = buildAnomalyPatternPrompt(device: device, anomaly: anomaly,
                                               recentEvents: recentEvents)
        let response = try await session.respond(to: prompt, generating: AnomalyPattern.self)
        return response.content
    }

    // MARK: - AI Troubleshooter (AI-D7)

    static func aiTroubleshootingGuide(
        device: ThreadDevice,
        problem: String,
        anomaly: DeviceAnomaly?,
        recentEvents: [ActivityEvent],
        memoryFragment: String = ""
    ) async throws -> TroubleshootingGuide {
        let session = LanguageModelSession(
            instructions: sessionInstructions("""
            You are a Thread mesh network troubleshooter. Generate device-specific, \
            step-by-step troubleshooting instructions tailored to this exact device's \
            history and current state. Be practical and specific — avoid generic advice.\(languageInstruction)
            """)
        )
        let prompt = buildTroubleshootingPrompt(device: device, problem: problem,
                                                anomaly: anomaly, recentEvents: recentEvents,
                                                memoryFragment: memoryFragment)
        let response = try await session.respond(to: prompt, generating: TroubleshootingGuide.self)
        return response.content
    }

    // MARK: - Network Storyteller (AI-D10)

    static func networkStory(
        devices: [ThreadDevice],
        health: NetworkHealthScore,
        history: [HealthHistoryStore.Entry],
        events: [ActivityEvent]
    ) async throws -> NetworkNarrative {
        let session = LanguageModelSession(
            instructions: sessionInstructions("""
            You are a creative but factual network narrator. Tell the story of this Thread mesh \
            network over the past 30 days using the data provided. Make it engaging for a \
            non-technical smart home owner. Mention specific devices and events. \
            Keep it concise — under 200 words total.\(languageInstruction)
            """)
        )
        let prompt = buildNetworkStoryPrompt(devices: devices, health: health,
                                             history: history, events: events)
        let response = try await session.respond(to: prompt, generating: NetworkNarrative.self)
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

    private static func buildMaintenancePrompt(
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

    private static func buildAutoHealPrompt(
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

    private static func buildAlertScorePrompt(
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

    private static func buildCoachingPrompt(
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

    private static func buildAnomalyPatternPrompt(
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

    private static func buildTroubleshootingPrompt(
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

    private static func buildNetworkStoryPrompt(
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

    private static func buildTopologyDigestPrompt(diff: SnapshotDiff, deviceCount: Int) -> String {
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

// MARK: - Topology Change Digest (NF-3)

@available(iOS 26, *)
@Generable(description: "Plain-English summary of Thread mesh changes since the user last opened the app")
struct TopologyChangeSummary {
    @Guide(description: "1–2 sentences covering what changed: which devices joined, went offline, or had signal issues. Mention room names. Plain English, no jargon.")
    var headline: String

    @Guide(description: "1 sentence on whether the network is better, worse, or about the same overall.")
    var outlook: String
}

@available(iOS 26, *)
extension AINetworkAnalyzer {
    func topologyChangeSummary(diff: SnapshotDiff, deviceCount: Int) async -> (headline: String, outlook: String)? {
        let session = LanguageModelSession()
        let prompt = Self.buildTopologyDigestPrompt(diff: diff, deviceCount: deviceCount)
        guard let result = try? await session.respond(to: prompt, generating: TopologyChangeSummary.self) else { return nil }
        return (result.content.headline, result.content.outlook)
    }
}
