import SwiftUI

public enum OnboardingPage: CaseIterable, Identifiable {
    case welcome, setup, survey
    public var id: Self { self }
    public var title: String {
        switch self {
        case .welcome: "Welcome"
        case .setup: "Setup"
        case .survey: "Survey"
        }
    }
    public var text: String {
        switch self {
        case .welcome: "See every Thread device in your home, spot weak signal, and get alerted the moment something drops offline."
        case .setup: "ThreadMapper uses HomeKit to find your devices. You'll need a Thread border router — a HomePod mini, HomePod, or Apple TV 4K — set up in the Home app."
        case .survey: "Walk your home with the Survey tab to measure signal room by room. ThreadMapper builds a coverage picture and points out weak spots."
        }
    }
}

public struct OnboardingFlow: View {
    @Binding public var isPresented: Bool
    @State private var pageIndex: Int = 0
    private var canMoveBack: Bool { pageIndex > 0 }
    private var canMoveForward: Bool { pageIndex < OnboardingPage.allCases.count - 1 }

    public init(isPresented: Binding<Bool>) {
        _isPresented = isPresented
    }

    public var body: some View {
        VStack(spacing: 24) {
            Picker("Onboarding", selection: $pageIndex) {
                ForEach(Array(OnboardingPage.allCases.enumerated()), id: \.offset) { index, page in
                    Text(page.title).tag(index)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            let page = OnboardingPage.allCases[pageIndex]
            Text(page.title)
                .font(.largeTitle.bold())
            Text(page.text)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            HStack {
                if canMoveBack {
                    Button("Back") { pageIndex -= 1 }
                        .buttonStyle(.bordered)
                }
                if canMoveForward {
                    Button("Next") { pageIndex += 1 }
                        .buttonStyle(.borderedProminent)
                } else {
                    Button("Continue") {
                        isPresented = false
                    }
                    .buttonStyle(.borderedProminent)
                }
                Spacer()
            }
            .padding(.horizontal)

            HStack {
                Spacer()
                Button("Skip") { isPresented = false }
                    .buttonStyle(.bordered)
                    .font(.caption2)
                    .padding(.trailing, 4)
            }
            .padding(.top, 4)

            Spacer()
        }
        .padding(.vertical)
        .background(
            LinearGradient(
                colors: [Color.blue.opacity(0.15), Color.purple.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        )
    }
}
