import FoundationModels
import SwiftUI

@available(iOS 26, *)
struct MaintenanceCalendarView: View {
    @Environment(MeshViewModel.self) private var meshVM
    @Environment(ActivityStore.self) private var activityStore

    @State private var planState: PlanState = .idle

    enum PlanState {
        case idle, loading, done(MaintenancePlan), failed(String)
    }

    private static let timeframeOrder = ["Today", "This week", "This month"]

    var body: some View {
        List {
            switch planState {
            case .idle:
                EmptyView()
            case .loading:
                Section {
                    HStack(spacing: 12) {
                        ProgressView()
                        Text("Analysing your network history…")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)
                }
            case .done(let plan):
                planContent(plan)
            case .failed(let msg):
                Section {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                        Text(msg).font(.caption).foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Maintenance Calendar")
        .navigationBarTitleDisplayMode(.large)
        .task { await loadPlan() }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { Task { await loadPlan() } } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(isLoading)
            }
        }
    }

    private var isLoading: Bool {
        if case .loading = planState { return true }
        return false
    }

    @ViewBuilder
    private func planContent(_ plan: MaintenancePlan) -> some View {
        if !plan.summary.isEmpty {
            Section {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "calendar.badge.checkmark")
                        .font(.title2).foregroundStyle(.purple).frame(width: 32)
                    Text(plan.summary)
                        .font(.subheadline).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 4)
            }
        }

        let grouped = Dictionary(grouping: plan.tasks, by: \.timeframe)
        let ordered = (Self.timeframeOrder + grouped.keys
            .filter { !Self.timeframeOrder.contains($0) }.sorted())
            .filter { grouped[$0] != nil }

        ForEach(ordered, id: \.self) { timeframe in
            Section(timeframe) {
                ForEach(grouped[timeframe] ?? [], id: \.action) { task in
                    MaintenanceTaskRow(task: task)
                }
            }
        }
    }

    private func loadPlan() async {
        planState = .loading
        do {
            let plan = try await AINetworkAnalyzer.maintenancePlan(
                devices: meshVM.devices,
                anomalies: meshVM.anomalies,
                firmwareChanges: FirmwareHistoryStore.shared.changes,
                events: activityStore.events
            )
            planState = .done(plan)
        } catch {
            planState = .failed(error.localizedDescription)
        }
    }
}

// MARK: - Task row

@available(iOS 26, *)
private struct MaintenanceTaskRow: View {
    let task: MaintenanceTask

    private var priorityColor: Color {
        switch task.priority.lowercased() {
        case "critical": return .red
        case "high":     return .orange
        case "medium":   return .yellow
        default:         return .secondary
        }
    }

    private var categoryIcon: String {
        switch task.category.lowercased() {
        case "firmware":    return "arrow.up.circle"
        case "battery":     return "battery.25percent"
        case "signal":      return "wifi.exclamationmark"
        case "reliability": return "exclamationmark.triangle"
        default:            return "wrench.and.screwdriver"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: categoryIcon)
                    .font(.subheadline)
                    .foregroundStyle(priorityColor)
                    .frame(width: 22)
                Text(task.deviceName)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(task.priority.capitalized)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(priorityColor)
                    .padding(.horizontal, 7).padding(.vertical, 2)
                    .background(priorityColor.opacity(0.12), in: Capsule())
            }
            Text(task.action)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
            Text(task.reason)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 4)
    }
}
