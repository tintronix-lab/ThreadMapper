import SwiftUI

struct ActivityFeedView: View {
    @Environment(ActivityStore.self) private var store
    @State private var selectedDevice: ThreadDevice?

    private var grouped: [(day: Date, events: [ActivityEvent])] {
        let cal = Calendar.current
        let dict = Dictionary(grouping: store.events) { cal.startOfDay(for: $0.timestamp) }
        return dict.keys.sorted(by: >).map { day in (day: day, events: dict[day]!) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if store.events.isEmpty {
                    emptyState
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
            .toolbar {
                if !store.events.isEmpty {
                    ToolbarItem(placement: .primaryAction) {
                        Menu {
                            Button("Clear All Events", role: .destructive) {
                                store.clearAll()
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
            }
        }
    }

    // MARK: - Empty state

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
