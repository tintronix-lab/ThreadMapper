import WidgetKit
import SwiftUI

// MARK: - Data model (mirrors WidgetSnapshot from Sources/Shared)
// Kept local so the watchOS widget extension doesn't pull in iOS-only Shared files.

private struct WatchSnapshot: Codable {
    let grade: String
    let score: Int
    let deviceCount: Int
    let offlineCount: Int
    let updatedAt: Date
}

// MARK: - Timeline

private struct WatchEntry: TimelineEntry {
    let date: Date
    let snapshot: WatchSnapshot
}

private struct WatchProvider: TimelineProvider {
    func placeholder(in context: Context) -> WatchEntry {
        WatchEntry(date: Date(), snapshot: WatchSnapshot(grade: "A", score: 95, deviceCount: 8, offlineCount: 0, updatedAt: Date()))
    }

    func getSnapshot(in context: Context, completion: @escaping (WatchEntry) -> Void) {
        completion(WatchEntry(date: Date(), snapshot: load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WatchEntry>) -> Void) {
        let entry = WatchEntry(date: Date(), snapshot: load())
        // Refresh at most every 15 min; live updates arrive via WatchConnectivity
        let next = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date()
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    private func load() -> WatchSnapshot {
        guard let defaults = UserDefaults(suiteName: "group.com.tintronixlab.ThreadMapper"),
              let data = defaults.data(forKey: "networkSnapshot"),
              let full = try? JSONDecoder().decode(FullSnapshot.self, from: data)
        else {
            return WatchSnapshot(grade: "—", score: 0, deviceCount: 0, offlineCount: 0, updatedAt: Date())
        }
        return WatchSnapshot(grade: full.grade, score: full.score,
                             deviceCount: full.deviceCount, offlineCount: full.offlineCount,
                             updatedAt: full.updatedAt)
    }

    // Minimal decode shape — must match WidgetSnapshot JSON keys
    private struct FullSnapshot: Decodable {
        let grade: String
        let score: Int
        let deviceCount: Int
        let offlineCount: Int
        let updatedAt: Date
    }
}

// MARK: - Views

private struct ComplicationView: View {
    let entry: WatchEntry
    @Environment(\.widgetFamily) var family

    private var gradeColor: Color {
        switch entry.snapshot.grade {
        case "A": return .green
        case "B": return .mint
        case "C": return .yellow
        case "D": return .orange
        default:  return .red
        }
    }

    var body: some View {
        switch family {
        case .accessoryCircular:   circularView
        case .accessoryInline:     inlineView
        case .accessoryRectangular: rectangularView
        default:                   circularView
        }
    }

    private var circularView: some View {
        Gauge(value: Double(entry.snapshot.score), in: 0...100) {
            EmptyView()
        } currentValueLabel: {
            VStack(spacing: 0) {
                Text(entry.snapshot.grade)
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(gradeColor)
                if entry.snapshot.offlineCount > 0 {
                    Text("\(entry.snapshot.offlineCount)↓")
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(.red)
                }
            }
        }
        .gaugeStyle(.accessoryCircular)
        .tint(gradeColor)
    }

    @ViewBuilder
    private var inlineView: some View {
        if entry.snapshot.offlineCount > 0 {
            Text("Thread \(entry.snapshot.grade) · \(entry.snapshot.offlineCount) offline")
        } else {
            Text("Thread \(entry.snapshot.grade) · \(entry.snapshot.deviceCount) devices")
        }
    }

    private var rectangularView: some View {
        HStack(alignment: .center, spacing: 10) {
            Text(entry.snapshot.grade)
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(gradeColor)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(entry.snapshot.score)/100")
                    .font(.system(.footnote, design: .rounded, weight: .medium))
                Text("\(entry.snapshot.deviceCount) devices")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(.secondary)
                if entry.snapshot.offlineCount > 0 {
                    Text("\(entry.snapshot.offlineCount) offline")
                        .font(.system(.caption2, design: .rounded, weight: .semibold))
                        .foregroundStyle(.red)
                }
            }
            Spacer()
        }
    }
}

// MARK: - Widget entry point

@main
struct ThreadMapperWatchWidget: Widget {
    let kind = "ThreadMapperWatchWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WatchProvider()) { entry in
            ComplicationView(entry: entry)
        }
        .configurationDisplayName("Thread Network")
        .description("Shows your Thread mesh health on your watch face.")
        .supportedFamilies([.accessoryCircular, .accessoryInline, .accessoryRectangular])
    }
}
