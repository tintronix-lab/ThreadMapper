import SwiftUI

// MARK: - Main view

struct ResilienceSimulatorView: View {
    @Environment(MeshViewModel.self) private var meshVM
    @Environment(\.dismiss) private var dismiss
    @State private var impacts: [UUID: ResilienceSimulator.Impact] = [:]
    @State private var selectedImpact: ResilienceSimulator.Impact?

    // Nodes eligible for simulation: border routers + relays only
    private var analyzableNodes: [MeshNode] {
        meshVM.nodes
            .filter { $0.kind == .borderRouter || $0.kind == .router }
            .sorted {
                let a = impacts[$0.id]?.severity ?? .none
                let b = impacts[$1.id]?.severity ?? .none
                if a != b { return a > b }
                return $0.name < $1.name
            }
    }

    private func nodes(for severity: ResilienceSimulator.Impact.Severity) -> [MeshNode] {
        analyzableNodes.filter { impacts[$0.id]?.severity == severity }
    }

    var body: some View {
        NavigationStack {
            Group {
                if meshVM.nodes.filter({ $0.kind == .borderRouter || $0.kind == .router }).isEmpty {
                    emptyState
                } else {
                    nodeList
                }
            }
            .navigationTitle("Resilience Simulator")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(item: $selectedImpact) { impact in
                ImpactDetailView(impact: impact)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
            .onAppear {
                impacts = ResilienceSimulator.analyzeAll(nodes: meshVM.nodes)
            }
        }
    }

    // MARK: - Node list

    private var nodeList: some View {
        List {
            explanationSection

            let critical = nodes(for: .critical)
            let major    = nodes(for: .major)
            let minor    = nodes(for: .minor)
            let safe     = nodes(for: .none)

            if !critical.isEmpty {
                Section {
                    ForEach(critical) { node in nodeRow(node) }
                } header: {
                    Label("Single Points of Failure", systemImage: "xmark.shield.fill")
                        .foregroundStyle(.red)
                }
            }

            if !major.isEmpty {
                Section {
                    ForEach(major) { node in nodeRow(node) }
                } header: {
                    Label("High Impact", systemImage: "exclamationmark.shield.fill")
                        .foregroundStyle(.orange)
                }
            }

            if !minor.isEmpty {
                Section {
                    ForEach(minor) { node in nodeRow(node) }
                } header: {
                    Label("Low Impact", systemImage: "exclamationmark.shield")
                        .foregroundStyle(.yellow)
                }
            }

            if !safe.isEmpty {
                Section {
                    ForEach(safe) { node in nodeRow(node) }
                } header: {
                    Label("Safe to Remove", systemImage: "checkmark.shield.fill")
                        .foregroundStyle(.green)
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Node row

    @ViewBuilder
    private func nodeRow(_ node: MeshNode) -> some View {
        let impact = impacts[node.id]
        Button {
            selectedImpact = impact
        } label: {
            HStack(spacing: 12) {
                Image(systemName: impact?.severity.icon ?? "shield")
                    .font(.title3)
                    .foregroundStyle(severityColor(impact?.severity ?? .none))
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(node.name)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        nodeKindBadge(node.kind)
                    }
                    if let room = node.room {
                        Text(room)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 2) {
                    if let impact, impact.totalAffectedCount > 0 {
                        Text("\(impact.totalAffectedCount) affected")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(severityColor(impact.severity))
                    }
                    Text(impact?.severity.label ?? "")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.tertiaryLabel)
            }
            .padding(.vertical, 2)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Explanation section

    private var explanationSection: some View {
        Section {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "shield.lefthalf.filled.trianglebadge.exclamationmark")
                    .font(.title2)
                    .foregroundStyle(.blue)
                    .frame(width: 32)
                VStack(alignment: .leading, spacing: 4) {
                    Text("What If Analysis")
                        .font(.subheadline.weight(.semibold))
                    Text("Tap any border router or relay to see which devices would lose connectivity if it failed or was removed.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "shield.slash")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("No Routers Found")
                .font(.headline)
            Text("Resilience simulation requires at least one border router or relay in the mesh.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Helpers

    private func severityColor(_ severity: ResilienceSimulator.Impact.Severity) -> Color {
        switch severity {
        case .none:     return .green
        case .minor:    return .yellow
        case .major:    return .orange
        case .critical: return .red
        }
    }

    @ViewBuilder
    private func nodeKindBadge(_ kind: MeshNodeKind) -> some View {
        switch kind {
        case .borderRouter:
            Text("BR")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.blue)
                .padding(.horizontal, 5).padding(.vertical, 2)
                .background(.blue.opacity(0.12), in: Capsule())
        case .router:
            Text("Relay")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.indigo)
                .padding(.horizontal, 5).padding(.vertical, 2)
                .background(.indigo.opacity(0.12), in: Capsule())
        default:
            EmptyView()
        }
    }
}

// MARK: - Impact detail sheet

private struct ImpactDetailView: View {
    let impact: ResilienceSimulator.Impact
    @Environment(\.dismiss) private var dismiss
    @State private var narrationScenario: String?
    @State private var narrationFallback: String?
    @State private var isLoadingNarration = false

    private func severityColor(_ severity: ResilienceSimulator.Impact.Severity) -> Color {
        switch severity {
        case .none:     return .green
        case .minor:    return .yellow
        case .major:    return .orange
        case .critical: return .red
        }
    }

    var body: some View {
        NavigationStack {
            List {
                // Header
                Section {
                    HStack(spacing: 14) {
                        Image(systemName: impact.severity.icon)
                            .font(.largeTitle)
                            .foregroundStyle(severityColor(impact.severity))
                        VStack(alignment: .leading, spacing: 4) {
                            Text(impact.removedNode.name)
                                .font(.headline)
                                .lineLimit(2)
                            Text(impact.severity.label)
                                .font(.subheadline)
                                .foregroundStyle(severityColor(impact.severity))
                        }
                    }
                    .padding(.vertical, 6)
                }

                // Critical warning
                if impact.isSinglePointOfFailure {
                    Section {
                        Label {
                            Text("Only border router — all Thread devices would lose internet connectivity.")
                                .font(.subheadline)
                        } icon: {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.red)
                        }
                    }
                }

                // Summary
                Section("Impact Summary") {
                    summaryRow(
                        icon: "dot.radiowaves.right",
                        label: "Relays lost",
                        value: "\(impact.affectedRouterCount)",
                        color: .indigo
                    )
                    summaryRow(
                        icon: "sensor.tag.radiowaves.forward",
                        label: "End devices cut off",
                        value: "\(impact.affectedDeviceCount)",
                        color: .orange
                    )
                    summaryRow(
                        icon: "antenna.radiowaves.left.and.right",
                        label: "Border routers remaining",
                        value: impact.isLastBorderRouter
                            ? "0 — network isolated"
                            : "\(impact.totalBorderRouters - 1)",
                        color: impact.isLastBorderRouter ? .red : .blue
                    )
                }

                // AI narration (Pro + iOS 26)
                if ProStore.shared.isPro, #available(iOS 26, *) {
                    if isLoadingNarration || narrationScenario != nil {
                        Section("AI Impact Analysis") {
                            if isLoadingNarration {
                                HStack { ProgressView(); Spacer() }
                            } else {
                                HStack(alignment: .top, spacing: 10) {
                                    Image(systemName: "sparkles")
                                        .foregroundStyle(.purple)
                                    VStack(alignment: .leading, spacing: 6) {
                                        if let scenario = narrationScenario {
                                            Text(scenario).font(.subheadline)
                                        }
                                        if let fallback = narrationFallback {
                                            Text(fallback)
                                                .font(.subheadline)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.vertical, 2)
                            }
                        }
                    }
                }

                // Affected devices list
                if !impact.affectedNodes.isEmpty {
                    Section("Affected Devices") {
                        ForEach(impact.affectedNodes.sorted { $0.name < $1.name }) { node in
                            HStack(spacing: 10) {
                                Image(systemName: nodeIcon(node.kind))
                                    .foregroundStyle(nodeColor(node.kind))
                                    .frame(width: 22)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(node.name)
                                        .font(.subheadline)
                                        .lineLimit(1)
                                    if let room = node.room {
                                        Text(room)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                Text(node.kind.rawValue)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                // Recommendation
                Section("Recommendation") {
                    Label {
                        Text(impact.recommendation)
                            .font(.subheadline)
                            .fixedSize(horizontal: false, vertical: true)
                    } icon: {
                        Image(systemName: "lightbulb.fill")
                            .foregroundStyle(.yellow)
                    }
                    .padding(.vertical, 4)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Removal Impact")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                guard ProStore.shared.isPro else { return }
                guard #available(iOS 26, *) else { return }
                guard !isLoadingNarration, narrationScenario == nil else { return }
                isLoadingNarration = true
                if let narration = try? await AINetworkAnalyzer.resilienceNarration(impact: impact) {
                    narrationScenario = narration.scenario
                    narrationFallback = narration.fallback
                }
                isLoadingNarration = false
            }
        }
    }

    private func summaryRow(icon: String, label: String, value: String, color: Color) -> some View {
        HStack {
            Label(label, systemImage: icon)
                .font(.subheadline)
                .foregroundStyle(.primary)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(color)
        }
    }

    private func nodeIcon(_ kind: MeshNodeKind) -> String {
        switch kind {
        case .gateway:      return "globe"
        case .borderRouter: return "antenna.radiowaves.left.and.right"
        case .router:       return "dot.radiowaves.right"
        case .endDevice:    return "sensor.tag.radiowaves.forward"
        }
    }

    private func nodeColor(_ kind: MeshNodeKind) -> Color {
        switch kind {
        case .gateway:      return .gray
        case .borderRouter: return .blue
        case .router:       return .indigo
        case .endDevice:    return .green
        }
    }
}
