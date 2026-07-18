import SwiftUI

struct ChannelScannerView: View {
    @Environment(MeshViewModel.self) private var meshVM
    @Environment(\.dismiss) private var dismiss

    // MARK: - Channel model

    private struct ChannelInfo: Identifiable {
        let channel: Int
        let frequencyMHz: Int
        let deviceCount: Int
        let deviceNames: [String]
        let risk: Risk
        var id: Int { channel }
        var isInUse: Bool { deviceCount > 0 }

        enum Risk {
            case high, medium, low
            var label: LocalizedStringResource {
                switch self { case .high: "High"; case .medium: "Medium"; case .low: "Low" }
            }
            var color: Color {
                switch self { case .high: .red; case .medium: .orange; case .low: .green }
            }
        }
    }

    // MARK: - Computed data

    private static let highRisk:   Set<Int> = [11, 12, 13, 17, 18, 19, 22, 23, 24]
    private static let mediumRisk: Set<Int> = [14, 16, 20, 21, 25]

    private var channelData: [ChannelInfo] {
        let byChannel: [Int: [ThreadDevice]] = Dictionary(
            grouping: meshVM.devices.compactMap { d -> (Int, ThreadDevice)? in
                guard let ch = d.channel else { return nil }
                return (ch, d)
            }, by: \.0
        ).mapValues { $0.map(\.1) }

        return (11...26).map { ch in
            let devices = byChannel[ch] ?? []
            let risk: ChannelInfo.Risk
            if Self.highRisk.contains(ch)   { risk = .high }
            else if Self.mediumRisk.contains(ch) { risk = .medium }
            else                             { risk = .low }
            return ChannelInfo(
                channel: ch,
                frequencyMHz: 2405 + (ch - 11) * 5,
                deviceCount: devices.count,
                deviceNames: devices.map(\.name),
                risk: risk
            )
        }
    }

    private var recommendedChannels: [Int] {
        let all = channelData
        // 1. Prefer unused low-risk
        let unusedLow = all.filter { !$0.isInUse && $0.risk == .low }.map(\.channel)
        if !unusedLow.isEmpty { return Array(unusedLow.prefix(3)) }
        // 2. Unused medium-risk
        let unusedMedium = all.filter { !$0.isInUse && $0.risk == .medium }.map(\.channel)
        if !unusedMedium.isEmpty { return Array(unusedMedium.prefix(3)) }
        // 3. Any low-risk (in use or not)
        return all.filter { $0.risk == .low }.map(\.channel).prefix(3).map { $0 }
    }

    private var bestChannel: Int? { recommendedChannels.first }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    spectrumCard
                    if let best = bestChannel { recommendationCard(best: best) }
                    channelDetailList
                }
                .padding(16)
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("Channel Scanner")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: - Spectrum card

    private var spectrumCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("2.4 GHz Thread Spectrum", systemImage: "waveform.path")
                .font(.subheadline.weight(.semibold))

            let data = channelData
            let recommended = Set(recommendedChannels)

            Canvas { ctx, size in
                drawSpectrum(ctx: ctx, size: size, channels: data, recommended: recommended)
            }
            .frame(height: 110)

            HStack(spacing: 14) {
                legendDot(.red,    "High Wi-Fi overlap")
                legendDot(.orange, "Medium overlap")
                legendDot(.green,  "Low overlap")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)

            HStack(spacing: 14) {
                legendDot(.blue,   "Your mesh channel")
                HStack(spacing: 4) {
                    Text("★")
                        .font(.caption2)
                        .foregroundStyle(.yellow)
                    Text("Recommended")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(14)
        .background(Color(UIColor.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func drawSpectrum(ctx: GraphicsContext, size: CGSize,
                              channels: [ChannelInfo], recommended: Set<Int>) {
        let count  = CGFloat(channels.count)
        let barW   = size.width / count
        let baseY  = size.height - 18

        // Wi-Fi zone shading (ch 11-13 = WiFi 1, 16-18 = WiFi 6, 21-23 = WiFi 11)
        for (startCh, endCh) in [(11, 13), (16, 18), (21, 23)] {
            let x = CGFloat(startCh - 11) * barW
            let w = CGFloat(endCh - startCh + 1) * barW
            ctx.fill(Path(CGRect(x: x, y: 0, width: w, height: baseY)),
                     with: .color(.red.opacity(0.07)))
        }

        // Bars
        for (i, info) in channels.enumerated() {
            let x  = CGFloat(i) * barW + 2
            let w  = barW - 4
            let bH = info.isInUse ? (baseY - 20) : (baseY - 20) * 0.3
            let rect = CGRect(x: x, y: baseY - bH, width: w, height: bH)
            let rr   = Path(roundedRect: rect, cornerSize: CGSize(width: 2, height: 2))

            ctx.fill(rr, with: .color(info.risk.color.opacity(info.isInUse ? 0.85 : 0.25)))

            if info.isInUse {
                ctx.stroke(rr, with: .color(.blue.opacity(0.8)), lineWidth: 1.5)
            }

            // Recommended star
            if recommended.contains(info.channel) {
                let starY = baseY - bH - 14
                ctx.draw(
                    Text("★").font(.system(size: 9)).foregroundColor(.yellow),
                    in: CGRect(x: x, y: starY, width: w, height: 12)
                )
            }

            // Device count badge
            if info.deviceCount > 0 {
                ctx.draw(
                    Text("\(info.deviceCount)").font(.system(size: 7, weight: .bold)).foregroundColor(.white),
                    in: CGRect(x: x, y: baseY - bH + 2, width: w, height: 10)
                )
            }

            // Channel label
            ctx.draw(
                Text("\(info.channel)").font(.system(size: 7)).foregroundColor(.secondary),
                in: CGRect(x: x, y: baseY + 3, width: w, height: 12)
            )
        }
    }

    // MARK: - Recommendation card

    private func recommendationCard(best: Int) -> some View {
        let others = recommendedChannels.dropFirst()
        let info = channelData.first { $0.channel == best }

        return VStack(alignment: .leading, spacing: 10) {
            Label("Best Channel", systemImage: "star.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.yellow)

            HStack(alignment: .center, spacing: 14) {
                ZStack {
                    Circle()
                        .fill(info?.risk.color.opacity(0.15) ?? Color.green.opacity(0.15))
                        .frame(width: 56, height: 56)
                    VStack(spacing: 1) {
                        Text("CH")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text("\(best)")
                            .font(.system(.title, design: .rounded, weight: .bold))
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("\(info?.frequencyMHz ?? 0) MHz")
                        .font(.subheadline.weight(.medium))
                    (Text(info?.risk.label ?? "Low") + Text(" Wi-Fi interference risk"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if !others.isEmpty {
                        Text("Also good: CH \(others.map { "\($0)" }.joined(separator: ", "))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()
            }

            Text("Change the Thread network channel via your border router's web interface or OTBR commissioner. Devices rejoin automatically.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .background(Color(UIColor.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - Channel detail list

    private var channelDetailList: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("All Channels")
                .font(.subheadline.weight(.semibold))
                .padding(.bottom, 8)

            let data   = channelData
            let recom  = Set(recommendedChannels)

            ForEach(data) { info in
                channelRow(info: info, isRecommended: recom.contains(info.channel))
                if info.channel < 26 {
                    Divider().padding(.leading, 44)
                }
            }
        }
        .padding(14)
        .background(Color(UIColor.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    @ViewBuilder
    private func channelRow(info: ChannelInfo, isRecommended: Bool) -> some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(info.risk.color.opacity(0.15))
                    .frame(width: 32, height: 32)
                Text("\(info.channel)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(info.risk.color)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("CH \(info.channel)")
                        .font(.subheadline.weight(.medium))
                    if isRecommended {
                        Text("★ Best")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.yellow)
                            .padding(.horizontal, 5).padding(.vertical, 2)
                            .background(.yellow.opacity(0.15), in: Capsule())
                    }
                    if info.isInUse {
                        Text("In use")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.blue)
                            .padding(.horizontal, 5).padding(.vertical, 2)
                            .background(.blue.opacity(0.12), in: Capsule())
                    }
                }
                Text("\(info.frequencyMHz) MHz · \(info.risk.label) interference")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                if !info.deviceNames.isEmpty {
                    Text(info.deviceNames.joined(separator: ", "))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }

            Spacer()

            if info.deviceCount > 0 {
                Text("^[\(info.deviceCount) device](inflect: true)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
    }

    // MARK: - Helpers

    private func legendDot(_ color: Color, _ label: LocalizedStringKey) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(label)
        }
    }
}
