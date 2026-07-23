import SwiftUI

struct WatchDashboardView: View {
    @EnvironmentObject var store: WatchConnectivityStore

    private var gradeColor: Color {
        switch store.grade {
        case "A": return .green
        case "B": return .mint
        case "C": return .yellow
        case "D": return .orange
        default:  return .red
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                gradeRing
                deviceStats
                if store.borderRouterOffline { brAlert }
                lastUpdatedLabel
            }
            .padding(.horizontal, 4)
        }
        .navigationTitle("Thread")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var gradeRing: some View {
        ZStack {
            Gauge(value: store.score > 0 ? Double(store.score) : 0, in: 0...100) {
                EmptyView()
            } currentValueLabel: {
                VStack(spacing: 0) {
                    Text(store.grade)
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundStyle(gradeColor)
                    Text("\(store.score)")
                        .font(.system(.footnote, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
            .gaugeStyle(.accessoryCircular)
            .tint(gradeColor)
            .frame(width: 100, height: 100)
        }
    }

    private var deviceStats: some View {
        HStack(spacing: 24) {
            VStack(spacing: 2) {
                Text("\(store.deviceCount)")
                    .font(.system(.title3, design: .rounded, weight: .semibold))
                Text("Devices")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            if store.offlineCount > 0 {
                VStack(spacing: 2) {
                    Text("\(store.offlineCount)")
                        .font(.system(.title3, design: .rounded, weight: .semibold))
                        .foregroundStyle(.red)
                    Text("Offline")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var brAlert: some View {
        Label("Hub offline!", systemImage: "exclamationmark.triangle.fill")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.red)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(.red.opacity(0.15), in: Capsule())
    }

    @ViewBuilder
    private var lastUpdatedLabel: some View {
        if let updated = store.lastUpdated {
            HStack(spacing: 3) {
                Image(systemName: "clock").font(.caption2)
                Text(updated, style: .relative)
                    .font(.caption2)
            }
            .foregroundStyle(.tertiary)
        } else {
            Text("Open ThreadMapper\non iPhone")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
    }
}
