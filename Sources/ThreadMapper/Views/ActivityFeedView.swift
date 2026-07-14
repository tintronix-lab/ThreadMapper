import SwiftUI

struct ActivityFeedView: View {
    @Environment(ActivityStore.self) private var store
    @State private var selectedDevice: ThreadDevice?
    @State private var searchText = ""
    @State private var kindFilter: ActivityEvent.Kind? = nil
    @State private var showDeviceHistory = false
    @State private var showTimeline = false

    private var filtered: [ActivityEvent] {
        store.events.filter { event in
            let matchesKind = kindFilter.map { event.kind == $0 } ?? true
            guard matchesKind else { return false }
            guard !searchText.isEmpty else { return true }
            let q = searchText.lowercased()
            return event.detail.lowercased().contains(q)
                || event.kind.label.lowercased().contains(q)
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
                        ForEach(grouped, id: \.day) { group in
                            Section(dayHeader(group.day)) {
                                ForEach(group.events) { event in
                                    EventRow(event: event)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Activity")
            .searchable(text: $searchText, prompt: "Search events")
            .navigationDestination(isPresented: $showDeviceHistory) {
                DeviceHistoryView()
            }
            .navigationDestination(isPresented: $showTimeline) {
                NetworkTimelineView()
            }
            .toolbar {
                ToolbarItem(placement: .secondaryAction) {
                    Button {
                        showTimeline = true
                    } label: {
                        Label("Network Timeline", systemImage: "chart.xyaxis.line")
                    }
                }
                ToolbarItem(placement: .secondaryAction) {
                    Button {
                        showDeviceHistory = true
                    } label: {
                        Label("Device History", systemImage: "chart.bar.doc.horizontal")
                    }
                }
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

    // MARK: - Day header

    private func dayHeader(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) { return "Today" }
        if Calendar.current.isDateInYesterday(date) { return "Yesterday" }
        return date.formatted(.dateTime.weekday(.wide).month().day())
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
