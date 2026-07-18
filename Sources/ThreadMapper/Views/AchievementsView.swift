import SwiftUI

struct AchievementsView: View {
    @State private var store = AchievementStore.shared

    var body: some View {
        List(store.achievements) { achievement in
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(achievement.isUnlocked ? Color.yellow.opacity(0.15) : Color.secondary.opacity(0.08))
                        .frame(width: 44, height: 44)
                    Image(systemName: achievement.icon)
                        .font(.title3)
                        .foregroundStyle(achievement.isUnlocked ? Color.yellow : Color.secondary)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(LocalizedStringKey(achievement.title))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(achievement.isUnlocked ? .primary : .secondary)
                    Text(LocalizedStringKey(achievement.description))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    if let date = achievement.unlockedAt {
                        Text(date.formatted(.dateTime.day().month().year()))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }

                Spacer()

                if achievement.isUnlocked {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }
            .opacity(achievement.isUnlocked ? 1.0 : 0.45)
            .padding(.vertical, 2)
        }
        .navigationTitle("Achievements")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct AchievementBanner: View {
    let achievement: AchievementStore.Achievement
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: achievement.icon)
                .font(.title2)
                .foregroundStyle(.yellow)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 1) {
                Text("Achievement Unlocked")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(LocalizedStringKey(achievement.title))
                    .font(.subheadline.weight(.bold))
            }

            Spacer()

            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 16)
        .shadow(color: .black.opacity(0.12), radius: 8, y: 4)
    }
}
