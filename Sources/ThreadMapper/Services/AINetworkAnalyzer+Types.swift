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
