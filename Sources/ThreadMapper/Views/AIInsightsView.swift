import FoundationModels
import SwiftUI

@available(iOS 26, *)
struct AIInsightsView: View {
    @Environment(MeshViewModel.self) private var meshVM
    @Environment(ActivityStore.self) private var activityStore

    @State private var summaryState: SummaryState = .idle
    @State private var predictiveState: PredictiveState = .idle
    @State private var planState: PlanState = .idle
    @State private var rootCauseState: RootCauseState = .idle
    @State private var expansionState: ExpansionState = .idle
    @State private var healState: HealState = .idle
    @State private var report: NetworkDiagnosticsEngine.Report?

    private let model = SystemLanguageModel.default

    enum SummaryState {
        case idle, loading, done(MeshSummary), failed(String)
    }

    enum PredictiveState {
        case idle, loading, done(PredictiveAnalysis), failed(String)
    }

    enum PlanState {
        case idle, loading, done(OptimizationPlan), failed(String), skipped
    }

    enum RootCauseState {
        case idle, loading, done(RootCauseHypothesis), notApplicable, failed(String)
    }

    enum ExpansionState {
        case idle, loading, done(MeshExpansionPlan), failed(String)
    }

    enum HealState {
        case idle, loading, done(AutoHealReport), notApplicable, failed(String)
    }

    var body: some View {
        List {
            switch model.availability {
            case .available:
                assistantLinkSection
                availableContent
            case .unavailable(.appleIntelligenceNotEnabled):
                UnavailableRow(
                    icon: "apple.intelligence",
                    title: "Apple Intelligence Required",
                    message: "Enable Apple Intelligence in Settings → Apple Intelligence & Siri to use AI Insights.",
                    actionLabel: "Open Settings",
                    action: { UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!) }
                )
            case .unavailable(.deviceNotEligible):
                UnavailableRow(
                    icon: "iphone.slash",
                    title: "Device Not Supported",
                    message: "AI Insights requires an iPhone 16 or later with Apple Intelligence.",
                    actionLabel: nil, action: nil
                )
            case .unavailable(.modelNotReady):
                UnavailableRow(
                    icon: "arrow.down.circle",
                    title: "Model Downloading",
                    message: "The on-device AI model is still downloading. Try again in a few minutes.",
                    actionLabel: nil, action: nil
                )
            case .unavailable:
                UnavailableRow(
                    icon: "exclamationmark.triangle",
                    title: "AI Unavailable",
                    message: "On-device AI is temporarily unavailable.",
                    actionLabel: nil, action: nil
                )
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("AI Insights")
        .navigationBarTitleDisplayMode(.large)
        .task(id: meshVM.devices.count) {
            report = NetworkDiagnosticsEngine.analyze(devices: meshVM.devices)
            if model.isAvailable { await runAnalysis() }
        }
        .toolbar {
            if model.isAvailable {
                ToolbarItem(placement: .primaryAction) {
                    Button { Task { await runAnalysis() } } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    .disabled(isAnalyzing)
                }
                if let text = shareText {
                    ToolbarItem(placement: .primaryAction) {
                        ShareLink(item: text) {
                            Label("Share Analysis", systemImage: "square.and.arrow.up")
                        }
                    }
                }
            }
        }
    }

    // MARK: - Assistant link

    @ViewBuilder
    private var assistantLinkSection: some View {
        Section {
            NavigationLink(destination: NetworkAssistantWrapperView()) {
                AIInsightsLinkRow(
                    icon: "bubble.left.and.text.bubble.right.fill",
                    color: .purple,
                    title: "Network Assistant",
                    subtitle: "Ask anything about your mesh in plain English"
                )
            }
            NavigationLink(destination: MaintenanceCalendarView()) {
                AIInsightsLinkRow(
                    icon: "calendar.badge.checkmark",
                    color: .teal,
                    title: "Maintenance Calendar",
                    subtitle: "AI-prioritised tasks for firmware, battery, and signal health"
                )
            }
        }
    }

    // MARK: - Available content

    @ViewBuilder
    private var availableContent: some View {
        Section {
            HStack(spacing: 14) {
                Image(systemName: "apple.intelligence")
                    .font(.title2)
                    .foregroundStyle(.purple)
                    .frame(width: 36)
                VStack(alignment: .leading, spacing: 3) {
                    Text("On-Device AI Analysis")
                        .font(.headline)
                    Text("Powered by Apple Intelligence · Private & on-device")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.vertical, 4)
        }

        Section {
            switch summaryState {
            case .idle:
                EmptyView()
            case .loading:
                SummarySkeletonRow()
            case .done(let summary):
                SummaryCard(summary: summary)
            case .failed(let msg):
                ErrorRow(message: msg)
            }
        } header: {
            Label("Mesh Health Summary", systemImage: "waveform.path.ecg")
        }

        if case .done(let hypothesis) = rootCauseState {
            Section {
                RootCauseCard(hypothesis: hypothesis)
            } header: {
                Label("Root Cause Analysis", systemImage: "exclamationmark.magnifyingglass")
            } footer: {
                Text("Multiple devices showing the same degradation pattern may share a single root cause.")
                    .font(.caption)
            }
        } else if case .loading = rootCauseState {
            Section {
                HStack(spacing: 10) {
                    ProgressView().controlSize(.small)
                    Text("Correlating device issues…").font(.caption).foregroundStyle(.secondary)
                }
                .padding(.vertical, 6)
            } header: {
                Label("Root Cause Analysis", systemImage: "exclamationmark.magnifyingglass")
            }
        }

        switch planState {
        case .done(let plan):
            Section {
                OptimizationPlanRows(plan: plan)
            } header: {
                Label("Action Plan", systemImage: "checklist")
            } footer: {
                Text("AI-generated recommendations based on your current mesh state. All analysis is private and on-device.")
                    .font(.caption)
            }
        case .loading:
            Section {
                HStack(spacing: 10) {
                    ProgressView().controlSize(.small)
                    Text("Building optimisation plan…").font(.caption).foregroundStyle(.secondary)
                }
                .padding(.vertical, 6)
            } header: {
                Label("Action Plan", systemImage: "checklist")
            }
        case .failed(let msg):
            Section {
                ErrorRow(message: msg)
            } header: {
                Label("Action Plan", systemImage: "checklist")
            }
        default:
            EmptyView()
        }

        Section {
            switch predictiveState {
            case .idle:
                EmptyView()
            case .loading:
                HStack(spacing: 10) {
                    ProgressView().controlSize(.small)
                    Text("Analysing device risk…").font(.caption).foregroundStyle(.secondary)
                }
                .padding(.vertical, 6)
            case .done(let analysis):
                PredictiveAnalysisRows(analysis: analysis)
            case .failed(let msg):
                ErrorRow(message: msg)
            }
        } header: {
            Label("24-Hour Predictions", systemImage: "chart.line.uptrend.xyaxis")
        } footer: {
            Text("Predictions are based on recent offline history, signal strength, and mesh topology. All analysis is on-device and private.")
                .font(.caption)
        }

        switch expansionState {
        case .done(let plan):
            Section {
                ExpansionPlanRows(plan: plan)
            } header: {
                Label("Mesh Expansion Advisor", systemImage: "plus.circle.dashed")
            } footer: {
                Text("Recommendations for where to add Thread devices to improve coverage and reliability.")
                    .font(.caption)
            }
        case .loading:
            Section {
                HStack(spacing: 10) {
                    ProgressView().controlSize(.small)
                    Text("Finding expansion opportunities…").font(.caption).foregroundStyle(.secondary)
                }
                .padding(.vertical, 6)
            } header: {
                Label("Mesh Expansion Advisor", systemImage: "plus.circle.dashed")
            }
        case .failed(let msg):
            Section {
                ErrorRow(message: msg)
            } header: {
                Label("Mesh Expansion Advisor", systemImage: "plus.circle.dashed")
            }
        default:
            EmptyView()
        }

        switch healState {
        case .done(let report):
            Section {
                AutoHealRows(report: report)
            } header: {
                Label("Self-Healing Insights", systemImage: "wand.and.sparkles")
            } footer: {
                Text("Recurring patterns detected across sessions. Tap 'Mark Fixed' after applying a fix.")
                    .font(.caption)
            }
        case .loading:
            Section {
                HStack(spacing: 10) {
                    ProgressView().controlSize(.small)
                    Text("Analysing recurring patterns…").font(.caption).foregroundStyle(.secondary)
                }
                .padding(.vertical, 6)
            } header: {
                Label("Self-Healing Insights", systemImage: "wand.and.sparkles")
            }
        case .failed(let msg):
            Section {
                ErrorRow(message: msg)
            } header: {
                Label("Self-Healing Insights", systemImage: "wand.and.sparkles")
            }
        default:
            EmptyView()
        }
    }

    // MARK: - Share text

    private var shareText: String? {
        guard case .done(let summary) = summaryState else { return nil }
        var lines = [
            "ThreadMapper AI Analysis",
            "━━━━━━━━━━━━━━━━━━━━━━━",
            summary.headline,
            "",
            summary.explanation,
            "",
            "Recommended action: \(summary.topAction)"
        ]
        if case .done(let analysis) = predictiveState, !analysis.alerts.isEmpty {
            lines += ["", "24-Hour Predictions:"]
            for alert in analysis.alerts {
                lines.append("• \(alert.deviceName) [\(alert.riskLevel)] — \(alert.prediction)")
            }
            if !analysis.outlook.isEmpty {
                lines += ["", "Outlook: \(analysis.outlook)"]
            }
        }
        lines += ["", "Generated by ThreadMapper"]
        return lines.joined(separator: "\n")
    }

    // MARK: - Analysis runner

    private var isAnalyzing: Bool {
        if case .loading = summaryState { return true }
        if case .loading = predictiveState { return true }
        if case .loading = planState { return true }
        if case .loading = rootCauseState { return true }
        if case .loading = expansionState { return true }
        if case .loading = healState { return true }
        return false
    }

    private func runAnalysis() async {
        summaryState = .loading
        predictiveState = .loading
        planState = .loading
        expansionState = .loading
        healState = .loading
        let anomalyCount = meshVM.anomalies.values.filter { $0.trajectory != .stable }.count
        rootCauseState = anomalyCount >= 2 ? .loading : .notApplicable
        async let s: Void = fetchSummary()
        async let p: Void = fetchPredictive()
        async let pl: Void = fetchOptimizationPlan()
        async let rc: Void = fetchRootCause()
        async let ex: Void = fetchExpansionPlan()
        async let h: Void = fetchAutoHeal()
        _ = await (s, p, pl, rc, ex, h)
    }

    private func fetchOptimizationPlan() async {
        do {
            let result = try await AINetworkAnalyzer.optimizationPlan(
                devices: meshVM.devices,
                health: meshVM.health,
                anomalies: meshVM.anomalies,
                report: report
            )
            planState = .done(result)
        } catch {
            planState = .failed(error.localizedDescription)
        }
    }

    private func fetchRootCause() async {
        guard case .loading = rootCauseState else { rootCauseState = .notApplicable; return }
        do {
            let result = try await AINetworkAnalyzer.rootCauseAnalysis(
                devices: meshVM.devices,
                anomalies: meshVM.anomalies,
                report: report
            )
            rootCauseState = result.map { .done($0) } ?? .notApplicable
        } catch {
            rootCauseState = .failed(error.localizedDescription)
        }
    }

    private func fetchExpansionPlan() async {
        do {
            let result = try await AINetworkAnalyzer.meshExpansionPlan(
                devices: meshVM.devices,
                health: meshVM.health,
                report: report
            )
            expansionState = .done(result)
        } catch {
            expansionState = .failed(error.localizedDescription)
        }
    }

    private func fetchSummary() async {
        do {
            let result = try await AINetworkAnalyzer.meshSummary(
                devices: meshVM.devices,
                health: meshVM.health,
                report: report
            )
            summaryState = .done(result)
        } catch {
            summaryState = .failed(error.localizedDescription)
        }
    }

    private func fetchPredictive() async {
        do {
            let result = try await AINetworkAnalyzer.predictiveAnalysis(
                devices: meshVM.devices,
                offlineEvents: activityStore.events,
                report: report
            )
            predictiveState = .done(result)
        } catch {
            predictiveState = .failed(error.localizedDescription)
        }
    }

    private func fetchAutoHeal() async {
        let memory = AIMemoryStore.shared
        let recurringOffline = memory.recurringOfflineDevices(threshold: 3)
        let memoryFragments = meshVM.devices.compactMap { d -> String? in
            let frag = memory.summaryPromptFragment(for: d.uniqueIdentifier)
            return frag.isEmpty ? nil : frag
        }
        do {
            if let result = try await AINetworkAnalyzer.autoHealReport(
                devices: meshVM.devices,
                anomalies: meshVM.anomalies,
                events: activityStore.events,
                recurringOffline: recurringOffline,
                memoryFragments: memoryFragments
            ) {
                healState = .done(result)
            } else {
                healState = .notApplicable
            }
        } catch {
            healState = .failed(error.localizedDescription)
        }
    }
}

// MARK: - Summary Card

@available(iOS 26, *)
private struct SummaryCard: View {
    let summary: MeshSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(summary.headline)
                .font(.headline)

            Text(summary.explanation)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "arrow.right.circle.fill")
                    .foregroundStyle(.purple)
                Text(summary.topAction)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.purple)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 2)
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Skeleton

private struct SummarySkeletonRow: View {
    @State private var phase: CGFloat = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            RoundedRectangle(cornerRadius: 4).fill(shimmer).frame(height: 16).frame(maxWidth: 260)
            RoundedRectangle(cornerRadius: 4).fill(shimmer).frame(height: 12).frame(maxWidth: .infinity)
            RoundedRectangle(cornerRadius: 4).fill(shimmer).frame(height: 12).frame(maxWidth: 200)
            RoundedRectangle(cornerRadius: 4).fill(shimmer).frame(height: 12).frame(maxWidth: 140)
        }
        .padding(.vertical, 8)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) { phase = 1 }
        }
    }

    private var shimmer: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: Color(.systemGray5), location: 0),
                .init(color: Color(.systemGray4), location: phase),
                .init(color: Color(.systemGray5), location: 1)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}

// MARK: - Predictive rows

@available(iOS 26, *)
private struct PredictiveAnalysisRows: View {
    let analysis: PredictiveAnalysis

    var body: some View {
        if analysis.alerts.isEmpty {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.shield.fill").foregroundStyle(.green)
                Text("No devices at elevated risk in the next 24 hours.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        } else {
            ForEach(analysis.alerts, id: \.deviceName) { alert in
                DeviceRiskRow(alert: alert)
            }
        }

        if !analysis.outlook.isEmpty {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "calendar.badge.clock")
                    .foregroundStyle(.secondary).font(.caption).padding(.top, 2)
                Text(analysis.outlook)
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 2)
        }
    }
}

@available(iOS 26, *)
private struct DeviceRiskRow: View {
    let alert: DeviceRiskAlert

    private var riskColor: Color {
        switch alert.riskLevel.lowercased() {
        case "high": return .red
        case "medium": return .orange
        default: return .yellow
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Circle().fill(riskColor).frame(width: 8, height: 8)
                Text(alert.deviceName).font(.subheadline.weight(.medium))
                Spacer()
                Text(alert.riskLevel.capitalized)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(riskColor)
                    .padding(.horizontal, 8).padding(.vertical, 2)
                    .background(riskColor.opacity(0.12), in: Capsule())
            }
            Text(alert.prediction).font(.caption).foregroundStyle(.secondary)
            HStack(spacing: 4) {
                Image(systemName: "lightbulb.fill").font(.caption2).foregroundStyle(.orange)
                Text(alert.action).font(.caption).foregroundStyle(.orange)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Unavailable / Error rows

private struct UnavailableRow: View {
    let icon: String
    let title: String
    let message: String
    let actionLabel: String?
    let action: (() -> Void)?

    var body: some View {
        Section {
            VStack(spacing: 14) {
                Image(systemName: icon).font(.largeTitle).foregroundStyle(.secondary)
                Text(title).font(.headline)
                Text(message).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                if let label = actionLabel, let action {
                    Button(label, action: action).buttonStyle(.borderedProminent).controlSize(.small)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
        }
    }
}

private struct ErrorRow: View {
    let message: String
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
            Text(message).font(.caption).foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Optimization Plan Rows

@available(iOS 26, *)
private struct OptimizationPlanRows: View {
    let plan: OptimizationPlan

    private func impactColor(_ impact: String) -> Color {
        switch impact.lowercased() {
        case "high":   return .red
        case "medium": return .orange
        default:       return .secondary
        }
    }

    var body: some View {
        ForEach(Array(plan.insights.enumerated()), id: \.offset) { idx, insight in
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text("\(idx + 1)")
                        .font(.caption2.weight(.black))
                        .foregroundStyle(.white)
                        .frame(width: 18, height: 18)
                        .background(impactColor(insight.impact), in: Circle())

                    Text(insight.title)
                        .font(.subheadline.weight(.semibold))

                    Spacer()
                    if insight.estimatedImprovementPercent > 0 {
                        Text("+\(insight.estimatedImprovementPercent)%")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.green)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Color.green.opacity(0.12), in: Capsule())
                    }
                }
                Text(insight.problem)
                    .font(.caption).foregroundStyle(.secondary)
                HStack(spacing: 4) {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.caption2).foregroundStyle(.purple)
                    Text(insight.action)
                        .font(.caption.weight(.medium)).foregroundStyle(.purple)
                }
            }
            .padding(.vertical, 4)
        }

        if !plan.outlook.isEmpty {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "calendar.badge.checkmark")
                    .font(.caption2).foregroundStyle(.secondary).padding(.top, 2)
                Text(plan.outlook).font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 2)
        }
    }
}

// MARK: - Expansion Plan Rows

@available(iOS 26, *)
private struct ExpansionPlanRows: View {
    let plan: MeshExpansionPlan

    var body: some View {
        ForEach(Array(plan.spots.enumerated()), id: \.offset) { _, spot in
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    ZStack {
                        Circle().fill(Color.blue.opacity(0.12)).frame(width: 28, height: 28)
                        Image(systemName: "plus").font(.caption.weight(.bold)).foregroundStyle(.blue)
                    }
                    VStack(alignment: .leading, spacing: 1) {
                        Text(spot.location).font(.subheadline.weight(.semibold))
                        Text(spot.deviceType).font(.caption2).foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                Text(spot.reason).font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up.circle.fill").font(.caption2).foregroundStyle(.blue)
                    Text(spot.expectedBenefit).font(.caption.weight(.medium)).foregroundStyle(.blue)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.vertical, 4)
        }

        if !plan.summary.isEmpty {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "signpost.right").font(.caption2).foregroundStyle(.secondary).padding(.top, 2)
                Text(plan.summary).font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 2)
        }
    }
}

// MARK: - Root Cause Card

@available(iOS 26, *)
private struct RootCauseCard: View {
    let hypothesis: RootCauseHypothesis

    private var confidenceColor: Color {
        switch hypothesis.confidence.lowercased() {
        case "high":   return .red
        case "medium": return .orange
        default:       return .secondary
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(confidenceColor)
                Text(hypothesis.rootCause)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(hypothesis.confidence.capitalized + " confidence")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(confidenceColor)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(confidenceColor.opacity(0.12), in: Capsule())
            }

            if !hypothesis.affectedDevices.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "dot.radiowaves.forward").font(.caption2).foregroundStyle(.secondary)
                    Text("Affected: \(hypothesis.affectedDevices.joined(separator: ", "))")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }

            if hypothesis.isNetworkWide {
                Label("Network-wide issue", systemImage: "network.badge.shield.half.filled")
                    .font(.caption2.weight(.semibold)).foregroundStyle(.orange)
            }

            HStack(alignment: .top, spacing: 4) {
                Image(systemName: "arrow.right.circle.fill").font(.caption2).foregroundStyle(.purple)
                Text(hypothesis.recommendedFix)
                    .font(.caption.weight(.medium)).foregroundStyle(.purple)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Auto-Heal Rows

@available(iOS 26, *)
private struct AutoHealRows: View {
    let report: AutoHealReport

    private func urgencyColor(_ urgency: String) -> Color {
        switch urgency.lowercased() {
        case "critical": return .red
        case "high":     return .orange
        default:         return .yellow
        }
    }

    var body: some View {
        if !report.networkPattern.isEmpty {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "wand.and.sparkles").font(.caption2).foregroundStyle(.purple).padding(.top, 2)
                Text(report.networkPattern).font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.bottom, 2)
        }
        ForEach(report.recommendations, id: \.deviceName) { rec in
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Circle().fill(urgencyColor(rec.urgency)).frame(width: 8, height: 8)
                    Text(rec.deviceName).font(.subheadline.weight(.semibold))
                    Spacer()
                    Text(rec.urgency.capitalized)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(urgencyColor(rec.urgency))
                        .padding(.horizontal, 7).padding(.vertical, 2)
                        .background(urgencyColor(rec.urgency).opacity(0.12), in: Capsule())
                }
                Text(rec.issuePattern).font(.caption).foregroundStyle(.secondary)
                Text(rec.rootCause).font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 4) {
                    Image(systemName: "wrench.and.screwdriver.fill").font(.caption2).foregroundStyle(.teal)
                    Text(rec.proposedFix).font(.caption.weight(.medium)).foregroundStyle(.teal)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.vertical, 4)
        }
    }
}

// MARK: - Shared link row

private struct AIInsightsLinkRow: View {
    let icon: String
    let color: Color
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(color.opacity(0.12)).frame(width: 38, height: 38)
                Image(systemName: icon).foregroundStyle(color).font(.subheadline)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(subtitle).font(.caption2).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Wrapper for older iOS

struct AIInsightsWrapperView: View {
    var body: some View {
        if #available(iOS 26, *) {
            AIInsightsView()
        } else {
            List {
                Section {
                    VStack(spacing: 12) {
                        Image(systemName: "apple.intelligence").font(.largeTitle).foregroundStyle(.secondary)
                        Text("iOS 26 Required").font(.headline)
                        Text("AI Insights requires iOS 26 or later with Apple Intelligence.")
                            .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("AI Insights")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}
