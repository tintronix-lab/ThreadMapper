import SwiftUI

// MARK: - Shareable Health Card

struct NetworkHealthCardView: View {
    let health: NetworkHealthScore
    let deviceCount: Int
    let offlineCount: Int
    let generatedAt: Date

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [health.color.opacity(0.85), health.color.opacity(0.35)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )

            VStack(spacing: 0) {
                // Header
                HStack {
                    Label("Thread Network", systemImage: "antenna.radiowaves.left.and.right")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Text(generatedAt.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                }
                .foregroundStyle(.white.opacity(0.85))

                Spacer()

                // Grade hero
                VStack(spacing: 10) {
                    Text(health.grade)
                        .font(.system(size: 108, weight: .black, design: .rounded))
                        .foregroundStyle(.white)

                    Text(health.summary)
                        .font(.headline)
                        .foregroundStyle(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                }

                Spacer()

                // Score bar
                VStack(spacing: 6) {
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(.white.opacity(0.25))
                            .frame(height: 10)
                        RoundedRectangle(cornerRadius: 6)
                            .fill(.white)
                            .frame(width: CGFloat(health.score) / 100 * 280, height: 10)
                    }
                    .frame(width: 280)
                    Text("Score \(health.score) / 100")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.white.opacity(0.75))
                }

                Spacer()

                // Stat badges
                HStack(spacing: 40) {
                    HealthCardStat(
                        icon: "cpu",
                        value: "\(deviceCount)",
                        label: deviceCount == 1 ? "Device" : "Devices"
                    )
                    HealthCardStat(
                        icon: offlineCount == 0 ? "checkmark.circle.fill" : "wifi.slash",
                        value: offlineCount == 0 ? "All" : "\(offlineCount)",
                        label: offlineCount == 0 ? "Online" : "Offline",
                        accent: offlineCount > 0
                    )
                }
                .foregroundStyle(.white)

                Spacer()

                // Footer branding
                HStack {
                    Image(systemName: "network")
                    Text("ThreadMapper")
                        .fontWeight(.medium)
                    Spacer()
                }
                .font(.caption)
                .foregroundStyle(.white.opacity(0.6))
            }
            .padding(28)
        }
        .frame(width: 375, height: 667)
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }
}

private struct HealthCardStat: View {
    let icon: String
    let value: String
    let label: LocalizedStringKey
    var accent = false

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(accent ? Color.red.opacity(0.9) : Color.white)
            Text(value)
                .font(.title.weight(.bold).monospacedDigit())
            Text(label)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.8))
        }
    }
}

// MARK: - Share sheet wrapper

struct HealthCardShareSheet: View {
    let image: UIImage
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal)
                    .shadow(color: .black.opacity(0.12), radius: 12, y: 4)

                ShareLink(item: Image(uiImage: image), preview: SharePreview("Thread Network Health", image: Image(uiImage: image))) {
                    Label("Share Health Card", systemImage: "square.and.arrow.up")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.blue)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal)
                }
            }
            .navigationTitle("Health Card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
