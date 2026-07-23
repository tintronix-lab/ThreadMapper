import SwiftUI

// MARK: - NF-3: Topology Change Digest

struct TopologyChangeDigestView: View {
    let diff: SnapshotDiff
    let deviceCount: Int
    @Environment(\.dismiss) private var dismiss
    @Environment(ProStore.self) private var proStore

    @State private var aiHeadline: String?
    @State private var aiOutlook: String?
    @State private var isLoadingAI = false

    private var timeAgoLabel: String {
        let interval = -diff.baselineAt.timeIntervalSinceNow
        if interval < 3600 { return "a few minutes ago" }
        let hours = Int(interval / 3600)
        if hours < 24 { return "\(hours)h ago" }
        return "\(Int(hours / 24))d ago"
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 10) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.title2)
                            .foregroundStyle(.blue)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Since \(timeAgoLabel)")
                                .font(.subheadline.weight(.semibold))
                            Text("\(diff.changes.count) change\(diff.changes.count == 1 ? "" : "s") detected")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }

                if !diff.regressions.isEmpty {
                    Section("Issues") {
                        ForEach(diff.regressions) { change in
                            ChangeRow(change: change)
                        }
                    }
                }

                if !diff.improvements.isEmpty {
                    Section("Improvements") {
                        ForEach(diff.improvements) { change in
                            ChangeRow(change: change)
                        }
                    }
                }

                if proStore.isPro {
                    Section {
                        if isLoadingAI {
                            HStack(spacing: 8) {
                                ProgressView()
                                Text("Generating AI summary…")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } else if let headline = aiHeadline {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(spacing: 5) {
                                    Image(systemName: "sparkles")
                                        .foregroundStyle(.purple)
                                        .font(.caption)
                                    Text("AI Summary")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.purple)
                                }
                                Text(headline)
                                    .font(.subheadline)
                                if let outlook = aiOutlook {
                                    Text(outlook)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("What Changed")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                guard proStore.isPro, #available(iOS 26, *) else { return }
                isLoadingAI = true
                let result = await AINetworkAnalyzer().topologyChangeSummary(diff: diff, deviceCount: deviceCount)
                isLoadingAI = false
                aiHeadline = result?.headline
                aiOutlook = result?.outlook
            }
        }
    }
}

// MARK: - Change row

private struct ChangeRow: View {
    let change: SnapshotDiff.Change

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: change.kind.icon)
                .foregroundStyle(iconColor)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(change.name)
                    .font(.subheadline)
                if let room = change.room {
                    Text(room)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text(change.kind.label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(iconColor)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 2)
    }

    private var iconColor: Color {
        change.kind.isRegression ? .orange : .green
    }
}
