import WidgetKit
import SwiftUI

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
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular])
    }
}

// MARK: - Root view router

struct ThreadMapperWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: NetworkHealthEntry

    var body: some View {
        switch family {
        case .systemSmall:         SmallWidgetView(snap: entry.snapshot)
        case .systemMedium:        MediumWidgetView(snap: entry.snapshot)
        case .accessoryCircular:   CircularWidgetView(snap: entry.snapshot)
        case .accessoryRectangular: RectangularWidgetView(snap: entry.snapshot)
        default:                   SmallWidgetView(snap: entry.snapshot)
        }
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
                .font(.system(size: 11, weight: .semibold))
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
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundStyle(color)
                    Text("\(snap.score)")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(color.opacity(0.7))
                }
            }

            Spacer()

            HStack {
                Label("\(snap.deviceCount)", systemImage: "cpu")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
                if snap.offlineCount > 0 {
                    Label("\(snap.offlineCount)", systemImage: "wifi.slash")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.red)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.green)
                }
            }
        }
        .padding(12)
    }
}

// MARK: - Medium widget

struct MediumWidgetView: View {
    let snap: WidgetSnapshot
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
                            .font(.system(size: 26, weight: .black, design: .rounded))
                            .foregroundStyle(color)
                        Text("\(snap.score)")
                            .font(.system(size: 9, weight: .semibold, design: .monospaced))
                            .foregroundStyle(color.opacity(0.7))
                    }
                }
                Text(snap.offlineCount > 0 ? "\(snap.offlineCount) offline" : "All online")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(snap.offlineCount > 0 ? Color.red : Color.green)
            }

            // Divider
            Divider()

            // Right: room list
            VStack(alignment: .leading, spacing: 4) {
                Text("Network Health")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)

                ForEach(snap.rooms.prefix(4), id: \.name) { room in
                    HStack(spacing: 5) {
                        Image(systemName: roomIcon(room.name))
                            .font(.system(size: 9))
                            .foregroundStyle(room.offlineCount > 0 ? Color.red : Color.secondary)
                            .frame(width: 12)
                        Text(room.name)
                            .font(.system(size: 11))
                            .lineLimit(1)
                        Spacer()
                        if room.offlineCount > 0 {
                            Text("\(room.offlineCount)⚠")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(.red)
                        } else if room.weakCount > 0 {
                            Text("\(room.weakCount)~")
                                .font(.system(size: 9))
                                .foregroundStyle(.orange)
                        } else {
                            Image(systemName: "checkmark")
                                .font(.system(size: 8))
                                .foregroundStyle(.green)
                        }
                    }
                }

                Spacer()

                Text("Updated \(snap.updatedAt, style: .relative) ago")
                    .font(.system(size: 8))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(12)
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
                    .font(.system(size: 20, weight: .black, design: .rounded))
                if snap.offlineCount > 0 {
                    Text("\(snap.offlineCount)!")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.red)
                }
            }
        }
    }
}

// MARK: - Lock screen rectangular

struct RectangularWidgetView: View {
    let snap: WidgetSnapshot
    private var color: Color { gradeColor(snap.grade) }

    var body: some View {
        HStack(spacing: 8) {
            Text(snap.grade)
                .font(.system(size: 28, weight: .black, design: .rounded))
                .foregroundStyle(color)

            VStack(alignment: .leading, spacing: 2) {
                Text("Network Health")
                    .font(.system(size: 11, weight: .semibold))
                HStack(spacing: 6) {
                    Label("\(snap.deviceCount)", systemImage: "cpu")
                    if snap.offlineCount > 0 {
                        Label("\(snap.offlineCount)", systemImage: "wifi.slash")
                            .foregroundStyle(.red)
                    }
                }
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
            }
        }
    }
}
