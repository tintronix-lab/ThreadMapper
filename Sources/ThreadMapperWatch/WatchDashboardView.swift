import SwiftUI

struct WatchDashboardView: View {
    @EnvironmentObject var store: WatchConnectivityStore

    private var hasData: Bool { store.grade != "—" }

    private var gradeColor: Color {
        switch store.grade {
        case "A": return .green
        case "B": return .mint
        case "C": return .yellow
        case "D": return .orange
        case "—": return .gray
        default:  return .red
        }
    }

    private var statusText: String {
        if !hasData { return "Waiting for iPhone" }
        if store.offlineCount > 0 { return "\(store.offlineCount) offline" }
        return "All online"
    }

    var body: some View {
        VStack(spacing: 6) {
            gradeRing
            statusLine
            statTiles
            if store.borderRouterOffline { brAlert }
            if let updated = store.lastUpdated {
                lastUpdatedLabel(updated)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 6)
        .navigationTitle("Thread")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Grade ring

    private var gradeRing: some View {
        ZStack {
            Circle()
                .stroke(Color.primary.opacity(0.15), lineWidth: 7)
            Circle()
                .trim(from: 0, to: hasData ? CGFloat(store.score) / 100 : 0)
                .stroke(gradeColor, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: -2) {
                Text(store.grade)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(gradeColor)
                if hasData {
                    Text("\(store.score)")
                        .font(.system(.caption2, design: .rounded).weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: 66, height: 66)
    }

    // MARK: - Status line

    private var statusLine: some View {
        HStack(spacing: 5) {
            Circle().fill(gradeColor).frame(width: 6, height: 6)
            Text(statusText)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Stat tiles

    private var statTiles: some View {
        HStack(spacing: 6) {
            tile(value: "\(store.deviceCount)", label: "Devices", tint: .primary)
            tile(value: "\(store.offlineCount)", label: "Offline",
                 tint: store.offlineCount > 0 ? .red : .primary)
        }
    }

    private func tile(value: String, label: String, tint: Color) -> some View {
        VStack(spacing: 0) {
            Text(value)
                .font(.system(.title3, design: .rounded, weight: .semibold))
                .foregroundStyle(tint)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(Color.primary.opacity(0.10), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
    }

    // MARK: - Border-router alert

    private var brAlert: some View {
        Label("Hub offline", systemImage: "exclamationmark.triangle.fill")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.red)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 5)
            .background(.red.opacity(0.18), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
    }

    // MARK: - Footer

    private func lastUpdatedLabel(_ updated: Date) -> some View {
        HStack(spacing: 3) {
            Image(systemName: "clock")
            Text(updated, style: .relative)
        }
        .font(.caption2)
        .foregroundStyle(.tertiary)
    }
}
