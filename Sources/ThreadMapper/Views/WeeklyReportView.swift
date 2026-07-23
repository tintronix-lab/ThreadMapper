import SwiftUI
import Charts

struct WeeklyReportView: View {
    let report: WeeklyReportStore.Report
    @Environment(\.dismiss) private var dismiss

    private var gradeColor: Color { TMStyle.gradeColor(report.peakGrade) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    headerCard
                    scoreCard
                    if !report.gradeDistribution.isEmpty {
                        distributionCard
                    }
                    stabilityCard
                    streakCard
                    if !report.body.isEmpty {
                        summaryCard
                    }
                }
                .padding()
            }
            .navigationTitle(Text("Weekly Report", comment: "Nav title for weekly report"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(String(localized: "Done")) { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    ShareLink(item: shareText) {
                        Label(String(localized: "Share"), systemImage: "square.and.arrow.up")
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

    // MARK: - Score Overview

    private var scoreCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader("Score Overview", icon: "gauge.with.needle")

            HStack(alignment: .lastTextBaseline, spacing: 6) {
                Text("\(report.avgScore)")
                    .font(.system(size: 52, weight: .black, design: .rounded))
                    .foregroundStyle(TMStyle.gradeColor(report.peakGrade))
                Text("/ 100")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                Spacer()
                trendBadge
            }

            HStack(spacing: 10) {
                gradeChip(label: String(localized: "Peak"), grade: report.peakGrade)
                gradeChip(label: String(localized: "Lowest"), grade: report.lowestGrade)
                Spacer()
            }
        }
        .padding(20)
        .cardBackground(cornerRadius: 16)
    }

    @ViewBuilder
    private var trendBadge: some View {
        let delta = report.scoreDelta
        if delta == 0 {
            Label(String(localized: "Stable"), systemImage: "minus")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(.secondary.opacity(0.1), in: Capsule())
        } else {
            let up = delta > 0
            Label(up ? "+\(delta) pts" : "\(delta) pts",
                  systemImage: up ? "arrow.up.right" : "arrow.down.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(up ? .green : .orange)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background((up ? Color.green : Color.orange).opacity(0.1), in: Capsule())
        }
    }

    private func gradeChip(label: String, grade: String) -> some View {
        VStack(spacing: 2) {
            Text(grade)
                .font(.system(.title2, design: .rounded, weight: .black))
                .foregroundStyle(TMStyle.gradeColor(grade))
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(width: 54, height: 52)
        .background(TMStyle.gradeColor(grade).opacity(0.1),
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    // MARK: - Grade Distribution

    private var distributionCard: some View {
        let grades = ["A", "B", "C", "D", "F"]
        let total = report.gradeDistribution.values.reduce(0, +)
        guard total > 0 else { return AnyView(EmptyView()) }

        return AnyView(
            VStack(alignment: .leading, spacing: 14) {
                sectionHeader("Grade Distribution", icon: "chart.bar.fill")

                // Segmented bar
                Canvas { ctx, size in
                    var x: CGFloat = 0
                    for grade in grades {
                        let count = report.gradeDistribution[grade] ?? 0
                        guard count > 0 else { continue }
                        let w = size.width * CGFloat(count) / CGFloat(total)
                        ctx.fill(
                            Path(CGRect(x: x, y: 0, width: w, height: size.height)),
                            with: .color(TMStyle.gradeColor(grade))
                        )
                        x += w
                    }
                }
                .frame(height: 10)
                .clipShape(Capsule())

                // Legend
                HStack(spacing: 8) {
                    ForEach(grades, id: \.self) { grade in
                        let count = report.gradeDistribution[grade] ?? 0
                        guard count > 0 else { return AnyView(EmptyView()) }
                        let pct = Int(Double(count) / Double(total) * 100)
                        return AnyView(
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(TMStyle.gradeColor(grade))
                                    .frame(width: 7, height: 7)
                                Text("\(grade) \(pct)%")
                                    .font(.caption2.weight(.medium))
                                    .foregroundStyle(.secondary)
                            }
                        )
                    }
                    Spacer()
                }
            }
            .padding(20)
            .cardBackground(cornerRadius: 16)
        )
    }

    // MARK: - Stability

    private var stabilityCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader("Stability", icon: "shield.fill")

            HStack(spacing: 0) {
                // Total offline events
                statCell(
                    icon: "network.slash",
                    value: "\(report.offlineEventCount)",
                    label: String(localized: "Offline Events"),
                    tint: report.offlineEventCount == 0 ? .green : .orange
                )

                Divider().frame(height: 50)

                // Border router events
                statCell(
                    icon: "exclamationmark.octagon.fill",
                    value: "\(report.borderRouterEventCount)",
                    label: String(localized: "Border Router"),
                    tint: report.borderRouterEventCount == 0 ? .green : .red
                )

                Divider().frame(height: 50)

                // Most affected device
                statCell(
                    icon: "cpu.fill",
                    value: report.mostProblematicDevice.map { shortName($0) } ?? "—",
                    label: String(localized: "Most Affected"),
                    tint: report.mostProblematicDevice == nil ? .green : .orange
                )
            }

            if report.offlineEventCount == 0 {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                    Text("No offline events this week — excellent stability.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(20)
        .cardBackground(cornerRadius: 16)
    }

    // MARK: - Streak

    private var streakCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader("Consistency", icon: "flame.fill")

            HStack(spacing: 0) {
                statCell(
                    icon: "flame.fill",
                    value: report.streakDays >= 1 ? "\(report.streakDays)" : "—",
                    label: String(localized: "Day Streak"),
                    tint: report.streakDays >= 3 ? .orange : .secondary
                )
                Divider().frame(height: 50)
                statCell(
                    icon: "star.fill",
                    value: "\(report.totalADays)",
                    label: String(localized: "Grade A Days"),
                    tint: .yellow
                )
                Divider().frame(height: 50)
                statCell(
                    icon: "calendar.badge.checkmark",
                    value: "\(report.avgScore)",
                    label: String(localized: "Avg Score"),
                    tint: TMStyle.gradeColor(report.peakGrade)
                )
            }
        }
        .padding(20)
        .cardBackground(cornerRadius: 16)
    }

    // MARK: - AI Summary

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("Summary", icon: "text.alignleft")
            Text(report.body)
                .font(.body)
                .lineSpacing(4)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(20)
        .cardBackground(cornerRadius: 16)
    }

    // MARK: - Helpers

    private func sectionHeader(_ key: String.LocalizationValue, icon: String) -> some View {
        Label(String(localized: key), systemImage: icon)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
    }

    private func statCell(icon: String, value: String, label: String, tint: Color) -> some View {
        VStack(spacing: 5) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(tint)
            Text(value)
                .font(.headline.weight(.bold).monospacedDigit())
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
    }

    private func shortName(_ name: String) -> String {
        let words = name.split(separator: " ")
        if words.count > 2 { return String(words.prefix(2).joined(separator: " ")) }
        return name
    }

    private var shareText: String {
        var lines: [String] = [
            "ThreadMapper – \(String(localized: "Weekly Report"))",
            report.weekRangeLabel,
            "",
            report.body,
            "",
            "\(String(localized: "Avg Score")): \(report.avgScore)/100",
            "\(String(localized: "Peak")): \(report.peakGrade)  \(String(localized: "Lowest")): \(report.lowestGrade)",
        ]
        if report.scoreDelta != 0 {
            let sign = report.scoreDelta > 0 ? "+" : ""
            lines.append("\(String(localized: "Trend")): \(sign)\(report.scoreDelta) pts")
        }
        lines.append("\(String(localized: "Offline Events")): \(report.offlineEventCount)")
        if report.streakDays >= 1 {
            lines.append("\(String(localized: "Day Streak")): \(report.streakDays)")
        }
        return lines.joined(separator: "\n")
    }
}
