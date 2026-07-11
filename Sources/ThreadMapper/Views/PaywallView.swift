import SwiftUI
import StoreKit

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var proStore = ProStore.shared
    @State private var loadError = false

    private let features: [(icon: String, title: String, detail: String)] = [
        ("clock.arrow.circlepath",      "30-Day Health History",   "Track network trends over weeks, not just 24 hours"),
        ("chart.bar.fill",              "Mesh Resilience Score",   "Know which device failure would partition your mesh"),
        ("flame.fill",                  "Health Streaks",          "Track consecutive Grade A days across the year"),
        ("mic.fill",                    "Siri Shortcuts",          "Ask about your network without opening the app"),
        ("doc.text.fill",               "Weekly Reports",          "Plain-English summaries delivered every Sunday"),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    headerSection
                    featuresSection
                    purchaseSection
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }
            .navigationTitle("ThreadMapper Pro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Not Now") { dismiss() }
                        .foregroundStyle(.secondary)
                }
            }
        }
        .task { await proStore.loadProducts() }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.12))
                    .frame(width: 80, height: 80)
                Image(systemName: "network")
                    .font(.largeTitle)
                    .foregroundStyle(Color.accentColor)
            }
            VStack(spacing: 6) {
                Text("ThreadMapper Pro")
                    .font(.title2.bold())
                Text("The complete Thread network toolkit")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Features

    private var featuresSection: some View {
        VStack(spacing: 14) {
            ForEach(features, id: \.title) { f in
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.accentColor.opacity(0.12))
                            .frame(width: 36, height: 36)
                        Image(systemName: f.icon)
                            .foregroundStyle(Color.accentColor)
                            .imageScale(.small)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(f.title).font(.subheadline.weight(.semibold))
                        Text(f.detail).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "checkmark")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.green)
                }
            }
        }
        .padding(18)
        .background(Color(UIColor.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Purchase

    @ViewBuilder
    private var purchaseSection: some View {
        VStack(spacing: 12) {
            if proStore.products.isEmpty {
                // Products not yet loaded or unavailable
                ProgressView("Loading…")
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                ForEach(proStore.products, id: \.id) { product in
                    productButton(product)
                }
            }

            Button {
                Task { await proStore.restore() }
            } label: {
                Text("Restore Purchases")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 4)

            Text("Payment charged to your Apple ID. Subscriptions auto-renew unless cancelled at least 24 hours before the end of the period. Manage subscriptions in Settings.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.top, 4)
        }
    }

    @ViewBuilder
    private func productButton(_ product: Product) -> some View {
        let isAnnual = product.id == ProStore.annualID
        Button {
            Task {
                try? await proStore.purchase(product)
                if proStore.isPro { dismiss() }
            }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(product.displayName)
                            .font(.subheadline.weight(.semibold))
                        if isAnnual {
                            Text("Most Popular")
                                .font(.caption2.weight(.bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.orange.opacity(0.15), in: Capsule())
                                .foregroundStyle(.orange)
                        }
                    }
                    Text(product.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(product.displayPrice)
                    .font(.subheadline.weight(.bold))
            }
            .padding(16)
            .background(isAnnual ? Color.accentColor.opacity(0.1) : Color(UIColor.secondarySystemGroupedBackground),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                isAnnual ? RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.accentColor, lineWidth: 1.5) : nil
            )
        }
        .buttonStyle(.plain)
        .disabled(proStore.purchaseInProgress)
    }
}
