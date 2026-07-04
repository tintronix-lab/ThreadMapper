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
        case .welcome: "ThreadMapper maps Thread mesh coverage using SwiftUI, SwiftData, and HomeKit/Matter."
        case .setup: "Turn on Bluetooth, ensure a Thread border router is nearby, and grant location access if needed."
        case .survey: "Use Survey Walk to collect RSSI samples. The app generates coverage score and weak-spot hints."
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

            #if DEBUG
            HStack {
                Spacer()
                Button("Skip") { isPresented = false }
                    .buttonStyle(.bordered)
                    .font(.caption2)
                    .padding(.trailing, 4)
            }
            .padding(.top, 4)
            #endif

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
