import SwiftUI

/// Apple Watch remote for the iPhone's Guided Survey. Mirrors the current room
/// and recording state pushed from the phone and sends Start / Done / Skip
/// commands back. Requires the phone's Guided Survey screen to be open (it owns
/// the sampling); when it isn't, this shows a prompt.
struct GuidedSurveyControlView: View {
    @EnvironmentObject var store: WatchConnectivityStore

    var body: some View {
        VStack(spacing: 8) {
            if store.guidedActive {
                activeControls
            } else {
                idlePrompt
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 6)
        .navigationTitle("Survey")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Idle

    private var idlePrompt: some View {
        VStack(spacing: 10) {
            Image(systemName: "figure.walk.motion")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("Start a Guided Survey on your iPhone to control it from here.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 24)
    }

    // MARK: - Active

    private var activeControls: some View {
        VStack(spacing: 8) {
            HStack {
                Text("\(store.guidedCompleted)/\(store.guidedTotal) rooms")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                if store.guidedRecording {
                    HStack(spacing: 3) {
                        Circle().fill(.red).frame(width: 6, height: 6)
                        Text(timeString(store.guidedElapsed))
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.red)
                    }
                }
            }

            ProgressView(value: Double(store.guidedCompleted),
                         total: Double(max(store.guidedTotal, 1)))
                .tint(.accentColor)

            Text(store.guidedRoom ?? "—")
                .font(.title3.weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.top, 2)

            if store.guidedRecording {
                primaryButton("Done", icon: "checkmark.circle.fill", tint: .green) {
                    store.sendGuidedCommand("done")
                }
            } else {
                primaryButton("Start", icon: "record.circle", tint: .red) {
                    store.sendGuidedCommand("start")
                }
            }

            Button { store.sendGuidedCommand("skip") } label: {
                Text("Skip room").font(.caption2)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .disabled(store.guidedRecording)
            .padding(.top, 2)
        }
    }

    private func primaryButton(_ title: String, icon: String, tint: Color,
                               action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(tint)
        .controlSize(.large)
    }

    private func timeString(_ seconds: Int) -> String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}
