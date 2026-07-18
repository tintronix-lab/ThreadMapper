import SwiftUI

struct WeeklyReportView: View {
    let report: WeeklyReportStore.Report
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    headerCard
                    bodyCard
                    statsRow
                }
                .padding()
            }
            .navigationTitle("Weekly Report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .secondaryAction) {
                    ShareLink(item: shareText) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                }
            }
        }
    }

    // MARK: - Header

    private var headerCard: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(gradeColor.opacity(0.12))
                    .frame(width: 80, height: 80)
                Text(report.peakGrade)
                    .font(.system(.largeTitle, design: .rounded, weight: .black))
                    .foregroundStyle(gradeColor)
            }

            VStack(spacing: 4) {
                Text("Thread Network Report")
                    .font(.title3.weight(.bold))
                Text(report.weekRangeLabel)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    // MARK: - Body prose

    private var bodyCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(report.body)
                .font(.body)
                .lineSpacing(4)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(20)
        .cardBackground(cornerRadius: 16)
    }

    // MARK: - Stats row

    private var statsRow: some View {
        HStack(spacing: 0) {
            statChip(
                icon: "gauge.with.needle",
                value: report.avgScore > 0 ? "\(report.avgScore)" : "—",
                label: "Avg Score",
                tint: gradeColor
            )
            Divider().frame(height: 44)
            statChip(
                icon: "network.slash",
                value: "\(report.offlineEventCount)",
                label: "Offline Events",
                tint: report.offlineEventCount == 0 ? .green : .orange
            )
            Divider().frame(height: 44)
            statChip(
                icon: "flame.fill",
                value: report.streakDays >= 2 ? "\(report.streakDays)d" : "\(report.totalADays)",
                label: report.streakDays >= 2 ? "Day Streak" : "Grade A Days",
                tint: report.streakDays >= 2 ? .orange : .mint
            )
        }
        .padding(.vertical, 12)
        .cardBackground(cornerRadius: 16)
    }

    private func statChip(icon: String, value: String, label: String, tint: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundStyle(tint)
                .imageScale(.small)
            Text(value)
                .font(.headline.monospacedDigit())
                .foregroundStyle(.primary)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Helpers

    private var gradeColor: Color { TMStyle.gradeColor(report.peakGrade) }

    private var shareText: String {
        "ThreadMapper Weekly Report (\(report.weekRangeLabel))\n\n\(report.body)\n\nAvg Score: \(report.avgScore)/100 · Offline Events: \(report.offlineEventCount)"
    }
}
