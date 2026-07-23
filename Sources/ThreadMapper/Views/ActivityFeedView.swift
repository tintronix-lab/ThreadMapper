import SwiftUI

struct ActivityFeedView: View {
    @Environment(ActivityStore.self) private var store
    @Environment(MeshViewModel.self) private var meshVM
    @Environment(CommissioningBriefingStore.self) private var briefingStore
    @State private var selectedDevice: ThreadDevice?
    @State private var searchText = ""
    @State private var kindFilter: ActivityEvent.Kind? = nil
    @State private var showDeviceHistory = false
    @State private var showTimeline = false
    @State private var aiDigest: String? = nil
    @State private var isLoadingDigest = false
    // Comma-separated day keys (yyyy-MM-dd) of collapsed sections; default = all expanded.
    @AppStorage("activity.collapsedDays") private var collapsedDaysRaw = ""

    private var collapsedDays: Set<String> {
        Set(collapsedDaysRaw.split(separator: ",").map(String.init))
    }

    private func dayKey(_ date: Date) -> String {
        date.formatted(.dateTime.year().month().day())
    }

    private func toggleDay(_ key: String) {
        var days = collapsedDays
        if days.contains(key) { days.remove(key) } else { days.insert(key) }
        collapsedDaysRaw = days.joined(separator: ",")
    }

    private var filtered: [ActivityEvent] {
        store.events.filter { event in
            let matchesKind = kindFilter.map { event.kind == $0 } ?? true
            guard matchesKind else { return false }
            guard !searchText.isEmpty else { return true }
            let q = searchText.lowercased()
            return event.detail.lowercased().contains(q)
                || String(localized: event.kind.label).lowercased().contains(q)
                || (event.deviceName?.lowercased().contains(q) ?? false)
                || (event.room?.lowercased().contains(q) ?? false)
        }
    }

    private var grouped: [(day: Date, events: [ActivityEvent])] {
        let cal = Calendar.current
        let dict = Dictionary(grouping: filtered) { cal.startOfDay(for: $0.timestamp) }
        return dict.keys.sorted(by: >).map { day in (day: day, events: dict[day, default: []]) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if store.events.isEmpty {
                    emptyState
                } else if filtered.isEmpty {
                    noResultsState
                } else {
                    List {
                        if #available(iOS 26, *) {
                            let pending = briefingStore.briefings.values
                                .sorted { $0.generatedAt > $1.generatedAt }
                            if !pending.isEmpty {
                                Section {
                                    ForEach(pending, id: \.deviceID) { entry in
                                        CommissioningBriefingCard(entry: entry) {
                                            briefingStore.dismiss(entry.deviceID)
                                        }
                                    }
                                } header: {
                                    Label("New Device", systemImage: "sparkles")
                                }
                            }
                        }
                        if #available(iOS 26, *), isLoadingDigest || aiDigest != nil {
                            Section {
                                if isLoadingDigest {
                                    HStack(spacing: 10) {
                                        ProgressView().controlSize(.small)
                                        Text("Summarising activity…").font(.caption).foregroundStyle(.secondary)
                                    }
                                    .padding(.vertical, 4)
                                } else if let digest = aiDigest {
                                    HStack(alignment: .top, spacing: 10) {
                                        Image(systemName: "apple.intelligence")
                                            .foregroundStyle(.purple).font(.caption).padding(.top, 1)
                                        Text(digest)
                                            .font(.subheadline).foregroundStyle(.secondary)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                    .padding(.vertical, 4)
                                }
                            } header: {
                                Label("AI Summary", systemImage: "sparkles")
                            }
                        }
                        ForEach(grouped, id: \.day) { group in
                            let key = dayKey(group.day)
                            let expanded = !collapsedDays.contains(key)
                            Section {
                                if expanded {
                                    ForEach(group.events) { event in
                                        EventRow(event: event)
                                    }
                                }
                            } header: {
                                Button {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        toggleDay(key)
                                    }
                                } label: {
                                    HStack(spacing: 6) {
                                        Text(dayHeader(group.day))
                                            .font(.footnote.weight(.semibold))
                                            .foregroundStyle(.secondary)
                                        Spacer()
                                        if !expanded {
                                            Text("\(group.events.count)")
                                                .font(.caption2.monospacedDigit())
                                                .foregroundStyle(.tertiary)
                                        }
                                        Image(systemName: expanded ? "chevron.up" : "chevron.down")
                                            .font(.caption2.weight(.semibold))
                                            .foregroundStyle(.tertiary)
                                    }
                                    .textCase(nil)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        Section("Explore") {
                            Button { showTimeline = true } label: {
                                Label("Network Timeline", systemImage: "chart.xyaxis.line")
                            }
                            Button { showDeviceHistory = true } label: {
                                Label("Device History", systemImage: "chart.bar.doc.horizontal")
                            }
                        }
                    }
                }
            }
            .navigationTitle("Activity")
            .searchable(text: $searchText, prompt: "Search events")
            .task(id: store.events.count) {
                guard #available(iOS 26, *),
                      store.events.count >= 3,
                      !isLoadingDigest else { return }
                isLoadingDigest = true
                aiDigest = try? await AINetworkAnalyzer.activityDigest(
                    events: Array(store.events.prefix(10)),
                    devices: meshVM.devices
                )
                isLoadingDigest = false
            }
            .navigationDestination(isPresented: $showDeviceHistory) {
                DeviceHistoryView()
            }
            .navigationDestination(isPresented: $showTimeline) {
                NetworkTimelineView()
            }
            .toolbar {
                if !store.events.isEmpty {
                    ToolbarItem(placement: .primaryAction) {
                        Menu {
                            Section("Filter by type") {
                                Button {
                                    kindFilter = nil
                                } label: {
                                    Label("All Events", systemImage: kindFilter == nil ? "checkmark" : "list.bullet")
                                }
                                ForEach([
                                    ActivityEvent.Kind.deviceOffline,
                                    .deviceOnline,
                                    .borderRouterOffline,
                                    .healthDegraded,
                                    .healthImproved,
                                    .topologyJoined,
                                    .topologyLeft,
                                ], id: \.self) { kind in
                                    Button {
                                        kindFilter = kindFilter == kind ? nil : kind
                                    } label: {
                                        Label(kind.label, systemImage: kindFilter == kind ? "checkmark" : kind.icon)
                                    }
                                }
                            }
                            Divider()
                            ShareLink(item: exportText) {
                                Label("Export Activity Log", systemImage: "square.and.arrow.up")
                            }
                            Divider()
                            Button("Clear All Events", role: .destructive) {
                                store.clearAll()
                                kindFilter = nil
                            }
                        } label: {
                            Image(systemName: kindFilter != nil ? "line.3.horizontal.decrease.circle.fill" : "ellipsis.circle")
                        }
                    }
                }
            }
        }
    }

    // MARK: - Empty states

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.largeTitle)
                .foregroundStyle(.tertiary)
            Text("No Activity Yet")
                .font(.headline)
            Text("ThreadMapper records device events here as your network changes — offline alerts, topology shifts, and health score changes.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var noResultsState: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.largeTitle)
                .foregroundStyle(.tertiary)
            Text("No matching events")
                .font(.headline)
            if kindFilter != nil {
                Button("Clear Filter") { kindFilter = nil }
                    .font(.subheadline)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Export

    private var exportText: String {
        var lines = [
            "ThreadMapper Activity Log",
            "Exported \(Date().formatted(.dateTime.day().month().year().hour().minute()))",
            String(repeating: "─", count: 40)
        ]
        for group in grouped {
            lines.append("")
            lines.append(dayHeader(group.day).uppercased())
            for event in group.events {
                let time = event.timestamp.formatted(.dateTime.hour().minute())
                let room = event.room.map { " [\($0)]" } ?? ""
                lines.append("  \(time)  \(String(localized: event.kind.label))\(room)  \(event.detail)")
            }
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - Day header

    private func dayHeader(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) { return String(localized: "Today") }
        if Calendar.current.isDateInYesterday(date) { return String(localized: "Yesterday") }
        return date.formatted(.dateTime.weekday(.wide).month().day())
    }
}

// MARK: - Commissioning briefing card

private struct CommissioningBriefingCard: View {
    let entry: CommissioningBriefingEntry
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "apple.intelligence")
                    .foregroundStyle(.purple)
                    .font(.caption)
                Text(entry.deviceName)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                        .font(.body)
                }
                .buttonStyle(.plain)
            }
            Text(entry.roleExplanation)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(entry.topologyFit)
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(alignment: .top, spacing: 6) {
                Image(systemName: "lightbulb.fill")
                    .font(.caption2)
                    .foregroundStyle(.yellow)
                    .padding(.top, 1)
                Text(entry.recommendation)
                    .font(.caption)
                    .foregroundStyle(.primary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Event row

private struct EventRow: View {
    let event: ActivityEvent

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Icon
            Image(systemName: event.kind.icon)
                .foregroundStyle(event.kind.color)
                .imageScale(.medium)
                .frame(width: 24)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(event.kind.label)
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Text(event.timestamp, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                Text(event.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                if let room = event.room {
                    Text(room)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .padding(.top, 1)
                }
            }
        }
        .padding(.vertical, 2)
    }
}
