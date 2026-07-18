import SwiftUI

struct SmartHomeAdvisorView: View {
    @Environment(MeshViewModel.self) private var meshVM
    @Environment(ActivityStore.self) private var activityStore

    // Cached so UUIDs in each suggestion struct stay stable across redraws.
    // Recomputed only when the device count changes.
    @State private var placements: [SmartHomeAdvisor.PlacementSuggestion] = []
    @State private var automations: [SmartHomeAdvisor.AutomationSuggestion] = []
    @State private var scenes: [SmartHomeAdvisor.SceneRecommendation] = []

    @State private var expandedPlacement: UUID?
    @State private var expandedAutomation: UUID?
    @State private var expandedScene: UUID?

    var body: some View {
        List {
            advisorSummarySection

            if !placements.isEmpty {
                placementSection
            }

            if !automations.isEmpty {
                automationSection
            }

            if !scenes.isEmpty {
                sceneSection
            }

            if placements.isEmpty && automations.isEmpty && scenes.isEmpty {
                emptyState
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Smart Home Advisor")
        .navigationBarTitleDisplayMode(.large)
        .task(id: meshVM.devices.count) {
            let report = NetworkDiagnosticsEngine.analyze(devices: meshVM.devices)
            let advisor = SmartHomeAdvisor()
            placements = advisor.placementSuggestions(devices: meshVM.devices, report: report)
            automations = advisor.automationSuggestions(
                devices: meshVM.devices,
                offlineEvents: activityStore.events
            )
            scenes = advisor.sceneRecommendations(devices: meshVM.devices)
        }
    }

    // MARK: - Sections

    private var advisorSummarySection: some View {
        Section {
            HStack(spacing: 16) {
                Image(systemName: "wand.and.stars")
                    .font(.title2)
                    .foregroundStyle(.purple)
                    .frame(width: 36)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Personalised Recommendations")
                        .font(.headline)
                    Text("Based on ^[\(meshVM.devices.count) device](inflect: true) across your Thread mesh")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.vertical, 4)

            HStack(spacing: 0) {
                advisorStat(count: placements.count, label: "Placement", icon: "location.fill", color: .orange)
                Divider().frame(height: 40)
                advisorStat(count: automations.count, label: "Automation", icon: "bolt.fill", color: .blue)
                Divider().frame(height: 40)
                advisorStat(count: scenes.count, label: "Scene", icon: "theatermasks.fill", color: .purple)
            }
            .padding(.vertical, 6)
        }
    }

    private func advisorStat(count: Int, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundStyle(color)
            Text("\(count)").font(.title3.bold())
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var placementSection: some View {
        Section {
            ForEach(placements) { suggestion in
                PlacementRow(
                    suggestion: suggestion,
                    isExpanded: expandedPlacement == suggestion.id
                ) {
                    withAnimation {
                        expandedPlacement = expandedPlacement == suggestion.id ? nil : suggestion.id
                    }
                }
            }
        } header: {
            Label("Device Placement", systemImage: "location.fill")
        } footer: {
            Text("Placement suggestions are based on your current mesh topology and room coverage grades.")
                .font(.caption)
        }
    }

    private var automationSection: some View {
        Section {
            ForEach(automations) { suggestion in
                AutomationRow(
                    suggestion: suggestion,
                    isExpanded: expandedAutomation == suggestion.id
                ) {
                    withAnimation {
                        expandedAutomation = expandedAutomation == suggestion.id ? nil : suggestion.id
                    }
                }
            }
        } header: {
            Label("Automation Ideas", systemImage: "bolt.fill")
        } footer: {
            Text("These automations are set up in the Home app. ThreadMapper can't create automations directly, but provides the steps.")
                .font(.caption)
        }
    }

    private var sceneSection: some View {
        Section {
            ForEach(scenes) { scene in
                SceneRow(
                    scene: scene,
                    isExpanded: expandedScene == scene.id
                ) {
                    withAnimation {
                        expandedScene = expandedScene == scene.id ? nil : scene.id
                    }
                }
            }
        } header: {
            Label("Scene Recommendations", systemImage: "theatermasks.fill")
        } footer: {
            Text("Scenes group your Thread devices for quick activation. Create them in the Home app for best results.")
                .font(.caption)
        }
    }

    private var emptyState: some View {
        Section {
            VStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.green)
                Text("Your mesh looks great!")
                    .font(.headline)
                Text("No specific improvements detected right now. As your network changes, suggestions will appear here.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
        }
    }
}

// MARK: - Placement Row

private struct PlacementRow: View {
    let suggestion: SmartHomeAdvisor.PlacementSuggestion
    let isExpanded: Bool
    let onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onTap) {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(suggestion.priority.color.opacity(0.15))
                            .frame(width: 36, height: 36)
                        Image(systemName: suggestion.icon)
                            .font(.callout.weight(.medium))
                            .foregroundStyle(suggestion.priority.color)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(suggestion.title).font(.subheadline.weight(.medium))
                        HStack(spacing: 4) {
                            Text(suggestion.priority.label)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(suggestion.priority.color)
                            if let room = suggestion.room {
                                Text("·").font(.caption2).foregroundStyle(.tertiary)
                                Text(room).font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                    }

                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)
            .padding(.vertical, 6)

            if isExpanded {
                VStack(alignment: .leading, spacing: 10) {
                    Divider()
                    Text(suggestion.detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.up.circle.fill")
                            .foregroundStyle(.green)
                            .font(.caption)
                        Text(suggestion.impact)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.green)
                    }
                }
                .padding(.bottom, 8)
            }
        }
    }
}

// MARK: - Automation Row

private struct AutomationRow: View {
    let suggestion: SmartHomeAdvisor.AutomationSuggestion
    let isExpanded: Bool
    let onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onTap) {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.blue.opacity(0.12))
                            .frame(width: 36, height: 36)
                        Image(systemName: suggestion.icon)
                            .font(.callout.weight(.medium))
                            .foregroundStyle(.blue)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(suggestion.title).font(.subheadline.weight(.medium))
                        Text(suggestion.benefit)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)
            .padding(.vertical, 6)

            if isExpanded {
                VStack(alignment: .leading, spacing: 10) {
                    Divider()
                    Text(suggestion.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Steps")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.primary)
                        ForEach(Array(suggestion.steps.enumerated()), id: \.offset) { index, step in
                            HStack(alignment: .top, spacing: 8) {
                                Text("\(index + 1)")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(.white)
                                    .frame(width: 16, height: 16)
                                    .background(Color.blue, in: Circle())
                                Text(step)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .padding(.bottom, 6)
                }
            }
        }
    }
}

// MARK: - Scene Row

private struct SceneRow: View {
    let scene: SmartHomeAdvisor.SceneRecommendation
    let isExpanded: Bool
    let onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onTap) {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.purple.opacity(0.12))
                            .frame(width: 36, height: 36)
                        Image(systemName: scene.icon)
                            .font(.callout.weight(.medium))
                            .foregroundStyle(.purple)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(scene.name).font(.subheadline.weight(.medium))
                        Text("^[\(scene.devices.count) device](inflect: true) · \(scene.rooms.joined(separator: ", "))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)
            .padding(.vertical, 6)

            if isExpanded {
                VStack(alignment: .leading, spacing: 10) {
                    Divider()
                    Text(scene.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    if !scene.devices.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Include these devices")
                                .font(.caption.weight(.semibold))
                            FlowLayout(spacing: 6) {
                                ForEach(scene.devices, id: \.self) { name in
                                    Text(name)
                                        .font(.caption2)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(Color.purple.opacity(0.12), in: Capsule())
                                        .foregroundStyle(.purple)
                                }
                            }
                        }
                    }

                    HStack(spacing: 6) {
                        Image(systemName: "hand.tap.fill")
                            .font(.caption)
                            .foregroundStyle(.purple)
                        Text(scene.triggerSuggestion)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.bottom, 6)
                }
            }
        }
    }
}

// MARK: - FlowLayout for device chips

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > maxWidth, currentX > 0 {
                currentY += rowHeight + spacing
                currentX = 0
                rowHeight = 0
            }
            currentX += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: maxWidth, height: currentY + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        var currentX = bounds.minX
        var currentY = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > bounds.maxX, currentX > bounds.minX {
                currentY += rowHeight + spacing
                currentX = bounds.minX
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: currentX, y: currentY), proposal: ProposedViewSize(size))
            currentX += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
