import WidgetKit
import SwiftUI
import ActivityKit
import AppIntents

// MARK: - App Group read (widget-side)

private enum WidgetStore {
    static func readSnapshot() -> WidgetSnapshot? {
        guard let defaults = UserDefaults(suiteName: "group.com.tintronixlab.ThreadMapper"),
              let data = defaults.data(forKey: "networkSnapshot"),
              let snap = try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
        else { return nil }
        return snap
    }
}

// MARK: - Timeline

struct NetworkHealthEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> NetworkHealthEntry {
        NetworkHealthEntry(date: Date(), snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (NetworkHealthEntry) -> Void) {
        let snap = WidgetStore.readSnapshot() ?? .placeholder
        completion(NetworkHealthEntry(date: Date(), snapshot: snap))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NetworkHealthEntry>) -> Void) {
        let snap = WidgetStore.readSnapshot() ?? .placeholder
        let entry = NetworkHealthEntry(date: Date(), snapshot: snap)
        let next = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

// MARK: - Widget Entry Point

@main
struct ThreadMapperWidgetBundle: WidgetBundle {
    var body: some Widget {
        ThreadMapperWidget()
        ThreadNetworkLiveActivityWidget()
        if #available(iOS 18.0, *) {
            ScanNetworkControl()
        }
    }
}

struct ThreadMapperWidget: Widget {
    let kind = "ThreadMapperWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            ThreadMapperWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Network Health")
        .description("Shows your Thread mesh network health grade.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

// MARK: - Root view router

struct ThreadMapperWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: NetworkHealthEntry

    var body: some View {
        switch family {
        case .systemSmall:         SmallWidgetView(snap: entry.snapshot)
        case .systemMedium:        MediumWidgetView(snap: entry.snapshot, entryDate: entry.date)
        case .accessoryCircular:   CircularWidgetView(snap: entry.snapshot)
        case .accessoryRectangular: RectangularWidgetView(snap: entry.snapshot)
        case .accessoryInline:     InlineWidgetView(snap: entry.snapshot)
        default:                   SmallWidgetView(snap: entry.snapshot)
        }
    }
}

// MARK: - Live Activity Widget

struct ThreadNetworkLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ThreadNetworkActivityAttributes.self) { context in
            LiveActivityLockScreenView(state: context.state)
                .activityBackgroundTint(Color(.systemBackground).opacity(0.9))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(gradeColor(context.state.grade).opacity(0.18))
                                .frame(width: 46, height: 46)
                            VStack(spacing: 0) {
                                Text("Grade")
                                    .font(.system(size: 8, weight: .semibold))
                                    .foregroundStyle(gradeColor(context.state.grade).opacity(0.8))
                                Text(context.state.grade)
                                    .font(.system(.title2, design: .rounded, weight: .black))
                                    .foregroundStyle(gradeColor(context.state.grade))
                            }
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Thread Network")
                                .font(.caption.weight(.semibold))
                            Text("Score \(context.state.score) / 100")
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    let onlineCount = context.state.deviceCount - context.state.offlineCount
                    VStack(alignment: .trailing, spacing: 5) {
                        Label("\(onlineCount) online", systemImage: "wifi")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.green)
                        if context.state.offlineCount > 0 {
                            Label("\(context.state.offlineCount) offline", systemImage: "wifi.slash")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.red)
                        }
                        Text("of \(context.state.deviceCount) devices")
                            .font(.system(size: 9))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 8) {
                        // Score progress bar
                        HStack(spacing: 6) {
                            Text("Health")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(Color.secondary.opacity(0.2))
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(gradeColor(context.state.grade))
                                        .frame(width: geo.size.width * CGFloat(context.state.score) / 100)
                                }
                            }
                            .frame(height: 5)
                            Text("\(context.state.score)%")
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        // Alert row + dismiss
                        HStack(spacing: 6) {
                            if let alert = context.state.alertMessage {
                                Image(systemName: context.state.offlineCount > 0
                                      ? "exclamationmark.triangle.fill"
                                      : "checkmark.circle.fill")
                                    .foregroundStyle(context.state.offlineCount > 0 ? .orange : .green)
                                    .font(.caption2)
                                Text(alert)
                                    .font(.caption.weight(.medium))
                                    .lineLimit(1)
                            } else {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                    .font(.caption2)
                                Text("Mesh fully connected")
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button(intent: DismissLiveActivityIntent()) {
                                Label("Dismiss", systemImage: "xmark")
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.top, 6)
                }
            } compactLeading: {
                Text(context.state.grade)
                    .font(.system(.body, design: .rounded, weight: .black))
                    .foregroundStyle(gradeColor(context.state.grade))
            } compactTrailing: {
                if context.state.offlineCount > 0 {
                    Label("\(context.state.offlineCount)", systemImage: "wifi.slash")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.red)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption2)
                        .foregroundStyle(.green)
                }
            } minimal: {
                Text(context.state.grade)
                    .font(.system(.caption, design: .rounded, weight: .black))
                    .foregroundStyle(gradeColor(context.state.grade))
            }
        }
    }
}

private struct LiveActivityLockScreenView: View {
    let state: ThreadNetworkActivityAttributes.ContentState

    private var onlineCount: Int { state.deviceCount - state.offlineCount }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(gradeColor(state.grade).opacity(0.15))
                    .frame(width: 52, height: 52)
                VStack(spacing: 0) {
                    Text("Grade")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(gradeColor(state.grade).opacity(0.7))
                    Text(state.grade)
                        .font(.system(.title2, design: .rounded, weight: .black))
                        .foregroundStyle(gradeColor(state.grade))
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                if let alert = state.alertMessage {
                    Text(alert)
                        .font(.subheadline.weight(.semibold))
                } else {
                    Text("Thread Network")
                        .font(.subheadline.weight(.semibold))
                }
                HStack(spacing: 10) {
                    Label("\(onlineCount) online", systemImage: "wifi")
                        .foregroundStyle(.green)
                    if state.offlineCount > 0 {
                        Label("\(state.offlineCount) offline", systemImage: "wifi.slash")
                            .foregroundStyle(.red)
                    }
                    Text("· Score \(state.score)")
                        .foregroundStyle(.secondary)
                }
                .font(.caption)
            }
            Spacer()
            Button(intent: DismissLiveActivityIntent()) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                    .symbolRenderingMode(.hierarchical)
            }
            .buttonStyle(.plain)
        }
        .padding()
    }
}

// MARK: - Control Center Widget (iOS 18+)

@available(iOS 18.0, *)
struct ScanNetworkControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.tintronixlab.ThreadMapper.QuickView") {
            ControlWidgetButton(action: OpenThreadMapperIntent()) {
                Label("Thread Network", systemImage: "network")
            }
        }
        .displayName("Thread Network")
        .description("Open ThreadMapper to check your Thread mesh health.")
    }
}

@available(iOS 18.0, *)
struct OpenThreadMapperIntent: AppIntent {
    static let title: LocalizedStringResource = "Open ThreadMapper"
    static let openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        .result()
    }
}

// MARK: - Dismiss Live Activity intent (runs in-extension, never opens app)

struct DismissLiveActivityIntent: AppIntent {
    static let title: LocalizedStringResource = "Dismiss Live Activity"
    static let openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult {
        // Suppress re-creation from the app side until all devices recover.
        UserDefaults(suiteName: "group.com.tintronixlab.ThreadMapper")?
            .set(true, forKey: "liveActivityUserDismissed")
        for activity in Activity<ThreadNetworkActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        return .result()
    }
}

// MARK: - Interactive widget intent (iOS 17+)

struct RefreshWidgetIntent: AppIntent {
    static let title: LocalizedStringResource = "Refresh Network Status"
    static let openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        .result()
    }
}

// MARK: - Helpers

// Delegate to shared TMStyle (Sources/Shared) — single source of truth
// for grade colors and room icons across app and widget.
private func gradeColor(_ grade: String) -> Color { TMStyle.gradeColor(grade) }

private func roomIcon(_ name: String) -> String { TMStyle.roomIcon(name) }

// MARK: - Small widget

struct SmallWidgetView: View {
    let snap: WidgetSnapshot
    private var color: Color { gradeColor(snap.grade) }

    var body: some View {
        VStack(spacing: 6) {
            Text("ThreadMapper")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Spacer()

            ZStack {
                Circle()
                    .stroke(color.opacity(0.2), lineWidth: 5)
                    .frame(width: 72, height: 72)
                Circle()
                    .trim(from: 0, to: snap.grade == "—" ? 0 : CGFloat(snap.score) / 100)
                    .stroke(color, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .frame(width: 72, height: 72)
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 0) {
                    Text(snap.grade)
                        .font(.system(.title, design: .rounded, weight: .black))
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                        .foregroundStyle(color)
                    Text("\(snap.score)")
                        .font(.caption2.weight(.semibold).monospacedDigit())
                        .foregroundStyle(color.opacity(0.7))
                }
            }

            Spacer()

            HStack {
                Label("\(snap.deviceCount)", systemImage: "cpu")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                Spacer()
                if snap.offlineCount > 0 {
                    Label("\(snap.offlineCount)", systemImage: "wifi.slash")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.red)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption2)
                        .foregroundStyle(.green)
                }
            }
        }
        .padding(12)
        .widgetURL(URL(string: "threadmapper://dashboard")!)
    }
}

// MARK: - Medium widget

struct MediumWidgetView: View {
    let snap: WidgetSnapshot
    let entryDate: Date
    private var color: Color { gradeColor(snap.grade) }

    var body: some View {
        HStack(spacing: 14) {
            // Left: grade ring
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .stroke(color.opacity(0.2), lineWidth: 5)
                        .frame(width: 64, height: 64)
                    Circle()
                        .trim(from: 0, to: snap.grade == "—" ? 0 : CGFloat(snap.score) / 100)
                        .stroke(color, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                        .frame(width: 64, height: 64)
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 0) {
                        Text(snap.grade)
                            .font(.system(.title, design: .rounded, weight: .black))
                            .minimumScaleFactor(0.5)
                            .lineLimit(1)
                            .foregroundStyle(color)
                        Text("\(snap.score)")
                            .font(.caption2.weight(.semibold).monospacedDigit())
                            .foregroundStyle(color.opacity(0.7))
                    }
                }
                Text(snap.offlineCount > 0 ? "\(snap.offlineCount) offline" : "All online")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(snap.offlineCount > 0 ? Color.red : Color.green)
            }

            // Divider
            Divider()

            // Right: room list
            VStack(alignment: .leading, spacing: 4) {
                Text("Network Health")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                ForEach(snap.rooms.prefix(4), id: \.name) { room in
                    HStack(spacing: 5) {
                        Image(systemName: roomIcon(room.name))
                            .font(.caption2)
                            .foregroundStyle(room.offlineCount > 0 ? Color.red : Color.secondary)
                            .frame(width: 12)
                        Text(room.name)
                            .font(.caption)
                            .lineLimit(1)
                        Spacer()
                        if room.offlineCount > 0 {
                            Text("\(room.offlineCount)⚠")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.red)
                        } else if room.weakCount > 0 {
                            Text("\(room.weakCount)~")
                                .font(.caption2)
                                .foregroundStyle(.orange)
                        } else {
                            Image(systemName: "checkmark")
                                .font(.caption2)
                                .foregroundStyle(.green)
                        }
                    }
                }

                Spacer()

                HStack {
                    Text(entryDate.timeIntervalSince(snap.updatedAt) < 60
                         ? "Updated just now"
                         : "Updated \(snap.updatedAt, style: .relative)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Spacer()
                    Button(intent: RefreshWidgetIntent()) {
                        Image(systemName: "arrow.clockwise")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(12)
        .widgetURL(URL(string: "threadmapper://dashboard")!)
    }
}

// MARK: - Lock screen inline (single-line)

struct InlineWidgetView: View {
    let snap: WidgetSnapshot

    var body: some View {
        Label(
            snap.offlineCount > 0
                ? "Grade \(snap.grade) · \(snap.offlineCount) offline"
                : "Thread \(snap.grade) · \(snap.deviceCount) online",
            systemImage: snap.offlineCount > 0 ? "wifi.slash" : "checkmark.shield"
        )
        .widgetURL(URL(string: "threadmapper://dashboard")!)
    }
}

// MARK: - Lock screen circular

struct CircularWidgetView: View {
    let snap: WidgetSnapshot
    private var color: Color { gradeColor(snap.grade) }

    var body: some View {
        ZStack {
            Circle()
                .trim(from: 0, to: snap.grade == "—" ? 0 : CGFloat(snap.score) / 100)
                .stroke(color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Text(snap.grade)
                    .font(.system(.title3, design: .rounded, weight: .black))
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                if snap.offlineCount > 0 {
                    Text("\(snap.offlineCount)!")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.red)
                }
            }
        }
        .widgetURL(URL(string: "threadmapper://dashboard")!)
    }
}

// MARK: - Lock screen rectangular

struct RectangularWidgetView: View {
    let snap: WidgetSnapshot
    private var color: Color { gradeColor(snap.grade) }

    var body: some View {
        HStack(spacing: 8) {
            Text(snap.grade)
                .font(.system(.title, design: .rounded, weight: .black))
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .foregroundStyle(color)

            VStack(alignment: .leading, spacing: 2) {
                Text("Network Health")
                    .font(.caption.weight(.semibold))
                HStack(spacing: 6) {
                    Label("\(snap.deviceCount)", systemImage: "cpu")
                    if snap.offlineCount > 0 {
                        Label("\(snap.offlineCount)", systemImage: "wifi.slash")
                            .foregroundStyle(.red)
                    }
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
        }
        .widgetURL(URL(string: "threadmapper://dashboard")!)
    }
}
