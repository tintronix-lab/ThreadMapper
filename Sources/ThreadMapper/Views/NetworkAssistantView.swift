import SwiftUI
import FoundationModels

// MARK: - Model

private struct ChatMessage: Identifiable {
    let id = UUID()
    let role: Role
    let text: String
    let timestamp = Date()

    enum Role { case user, assistant }
}

// Computed so String(localized:) resolves at runtime in the active locale.
// Plain String values are needed so inputText receives the translated text
// rather than an untranslated key when the user taps a suggestion.
private var suggestedQuestions: [String] {
    [
        String(localized: "Why is my signal dropping?"),
        String(localized: "Which devices are at risk?"),
        String(localized: "How can I improve my mesh?"),
        String(localized: "Is my network ready for more devices?"),
        String(localized: "Which room has the worst coverage?"),
    ]
}

// MARK: - Main View

@available(iOS 26, *)
struct NetworkAssistantView: View {
    @ScaledMetric(relativeTo: .largeTitle) private var heroIconSize: CGFloat = 44
    @Environment(MeshViewModel.self)     private var meshVM
    @Environment(ActivityStore.self)     private var activityStore
    @Environment(DeviceStatsStore.self)  private var statsStore

    /// When set, the assistant focuses on this specific device.
    var focusDevice: ThreadDevice? = nil

    @State private var messages: [ChatMessage] = []
    @State private var inputText = ""
    @State private var isThinking = false
    @State private var streamingText: String? = nil
    @State private var session: LanguageModelSession?

    private let model = SystemLanguageModel.default

    var body: some View {
        VStack(spacing: 0) {
            if messages.isEmpty {
                welcomePane
            } else {
                messageList
            }
            Divider()
            inputBar
        }
        .navigationTitle(focusDevice.map { "AI: \($0.name)" } ?? "Network Assistant")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            setupSession()
            if let device = focusDevice, messages.isEmpty {
                autoAskAboutDevice(device)
            }
        }
    }

    // MARK: - Welcome

    private var welcomePane: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Image(systemName: "apple.intelligence")
                        .font(.system(size: heroIconSize))
                        .foregroundStyle(.purple)
                    Text("Ask anything about your network")
                        .font(.title3.weight(.semibold))
                    Text("I know your current mesh topology, signal levels, and device history.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.top, 40)

                VStack(alignment: .leading, spacing: 10) {
                    Text("Suggested questions")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                    ForEach(suggestedQuestions, id: \.self) { q in
                        Button {
                            inputText = q
                            send()
                        } label: {
                            HStack {
                                Text(q)
                                    .font(.subheadline)
                                    .multilineTextAlignment(.leading)
                                Spacer()
                                Image(systemName: "arrow.up.circle")
                                    .font(.subheadline)
                                    .foregroundStyle(.purple)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 11)
                            .cardBackground()
                            .padding(.horizontal)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.bottom, 20)
        }
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Message list

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(messages) { msg in
                        MessageBubbleView(message: msg)
                            .id(msg.id)
                    }
                    if isThinking {
                        if let text = streamingText {
                            StreamingBubbleView(text: text)
                                .id("streaming")
                                .padding(.bottom, 12)
                        } else {
                            ThinkingBubbleView()
                                .id("thinking")
                                .padding(.bottom, 12)
                        }
                    }
                }
                .padding(.top, 8)
            }
            .onChange(of: messages.count) {
                withAnimation(.easeOut(duration: 0.2)) {
                    proxy.scrollTo(messages.last?.id, anchor: .bottom)
                }
            }
            .onChange(of: streamingText) {
                if streamingText != nil {
                    proxy.scrollTo("streaming", anchor: .bottom)
                }
            }
            .onChange(of: isThinking) {
                if isThinking {
                    withAnimation { proxy.scrollTo("thinking", anchor: .bottom) }
                }
            }
        }
    }

    // MARK: - Input bar

    private var inputBar: some View {
        HStack(alignment: .bottom, spacing: 10) {
            TextField("Ask about your network…", text: $inputText, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...5)
                .font(.subheadline)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .cardBackground(cornerRadius: 22)
                .onSubmit { if !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { send() } }

            Button {
                send()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundStyle(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isThinking ? Color(.tertiaryLabel) : .purple)
            }
            .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isThinking)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }

    // MARK: - Session setup

    private var languageInstruction: String {
        let code = Locale.current.language.languageCode?.identifier ?? "en"
        guard code != "en" else { return "" }
        let name = Locale(identifier: "en").localizedString(forLanguageCode: code) ?? code
        return " Respond in \(name)."
    }

    private func setupSession() {
        guard session == nil, model.isAvailable else { return }
        let contextStr = focusDevice != nil ? buildDeviceContext(focusDevice!) : buildContext()
        let focus = focusDevice.map { "Focus on the specific device '\($0.name)' when possible. " } ?? ""
        session = LanguageModelSession(
            instructions: """
            You are a friendly Thread mesh network assistant inside ThreadMapper, helping a smart home user understand and improve their network. \
            \(focus)Answer questions about the current network state based on the data provided. \
            Keep answers concise (2–4 sentences), specific, and actionable. \
            Use plain English — say "signal strength" not RSSI, "hub" not border router, "relay device" not router. \
            Never mention acronyms without explanation. If you don't know something, say so honestly. \
            Current network snapshot:
            \(contextStr)\(languageInstruction)
            """
        )
    }

    private func buildDeviceContext(_ device: ThreadDevice) -> String {
        var lines: [String] = [
            "Focus device: \(device.name)\(device.room.map { " in \($0)" } ?? "").",
            "Status: \(device.isOffline ? "offline" : "online").",
        ]
        if let rssi = device.rssi {
            lines.append("Signal strength: \(rssi) dBm (\(rssi.rssiQualityLabel)).")
        }
        if let batt = device.batteryPercentage {
            lines.append("Battery: \(batt)%.")
        }
        if let anomaly = meshVM.anomalies[device.uniqueIdentifier] {
            lines.append("Signal trajectory: \(anomaly.trajectory.label) (dropped \(String(format: "%.0f", anomaly.dropDelta)) dBm from baseline).")
        }
        lines.append(contentsOf: [
            "Role: \(device.isBorderRouter ? "hub" : device.isRouter ? "relay device" : "end device").",
            "Overall mesh health: \(meshVM.health.score)/100 (grade \(meshVM.health.grade)).",
        ])
        return lines.joined(separator: " ")
    }

    private func autoAskAboutDevice(_ device: ThreadDevice) {
        let q = "Tell me about \(device.name) — is there anything I should know or any issues I should address?"
        inputText = q
        send()
    }

    private func buildContext() -> String {
        let devices = meshVM.devices
        let total = devices.count
        let offline = devices.filter(\.isOffline).count
        let brs = devices.filter(\.isBorderRouter)
        let anomalies = meshVM.anomalies

        var lines: [String] = [
            "Devices: \(total) total, \(offline) offline, \(total - offline) online.",
            "Hubs (border routers): \(brs.count) — \(brs.map(\.name).joined(separator: ", ")).",
            "Health score: \(meshVM.health.score)/100 (grade \(meshVM.health.grade)).",
        ]

        let criticalDevices = anomalies.values.filter { $0.trajectory == .critical }
        let decliningDevices = anomalies.values.filter { $0.trajectory == .declining }
        if !criticalDevices.isEmpty || !decliningDevices.isEmpty {
            let critNames = criticalDevices.compactMap { a in devices.first(where: { $0.uniqueIdentifier == a.deviceID })?.name }
            let declNames = decliningDevices.compactMap { a in devices.first(where: { $0.uniqueIdentifier == a.deviceID })?.name }
            if !critNames.isEmpty { lines.append("Critical signal drop: \(critNames.joined(separator: ", ")).") }
            if !declNames.isEmpty { lines.append("Declining signal: \(declNames.joined(separator: ", ")).") }
        }

        let weakDevices = devices.filter { ($0.rssi ?? 0) < -75 && !$0.isOffline }
        if !weakDevices.isEmpty {
            lines.append("Weak signal devices: \(weakDevices.map { "\($0.name) (\($0.rssi ?? 0) dBm)" }.joined(separator: ", ")).")
        }

        if !meshVM.health.issues.isEmpty {
            let issueText = meshVM.health.issues.prefix(3).map { String(localized: $0.message) }.joined(separator: "; ")
            lines.append("Top issues: \(issueText).")
        }

        return lines.joined(separator: " ")
    }

    // MARK: - Send

    private func send() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isThinking else { return }
        inputText = ""
        messages.append(ChatMessage(role: .user, text: text))
        isThinking = true
        streamingText = nil

        Task {
            defer {
                streamingText = nil
                isThinking = false
            }
            guard let session else {
                messages.append(ChatMessage(role: .assistant, text: String(localized: "AI is not available on this device. Please enable Apple Intelligence in Settings.")))
                return
            }
            do {
                let stream = session.streamResponse(to: text)
                for try await partial in stream {
                    streamingText = partial.content
                }
                messages.append(ChatMessage(role: .assistant, text: streamingText ?? ""))
            } catch {
                messages.append(ChatMessage(role: .assistant, text: String(localized: "Sorry, I couldn't process that. Please try again.")))
            }
        }
    }
}

// MARK: - Bubble Views

@available(iOS 26, *)
private struct MessageBubbleView: View {
    let message: ChatMessage

    private var isUser: Bool { message.role == .user }

    var body: some View {
        HStack {
            if isUser { Spacer(minLength: 60) }
            Text(message.text)
                .font(.subheadline)
                .foregroundStyle(isUser ? .white : .primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    isUser ? Color.purple : Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                )
            if !isUser { Spacer(minLength: 60) }
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 6)
    }
}

@available(iOS 26, *)
private struct StreamingBubbleView: View {
    let text: String
    @State private var showCursor = true

    var body: some View {
        HStack {
            Text(text + (showCursor ? "▎" : ""))
                .font(.subheadline)
                .foregroundStyle(.primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .cardBackground(cornerRadius: 18)
            Spacer(minLength: 60)
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 6)
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(500))
                showCursor.toggle()
            }
        }
    }
}

private struct ThinkingBubbleView: View {
    @State private var phase = 0

    var body: some View {
        HStack {
            HStack(spacing: 5) {
                ForEach(0..<3) { i in
                    Circle()
                        .fill(Color.secondary)
                        .frame(width: 7, height: 7)
                        .scaleEffect(phase == i ? 1.3 : 0.9)
                        .animation(
                            .easeInOut(duration: 0.4).repeatForever(autoreverses: true).delay(Double(i) * 0.15),
                            value: phase
                        )
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .cardBackground(cornerRadius: 18)
            Spacer(minLength: 60)
        }
        .padding(.horizontal, 14)
        .onAppear { phase = 1 }
    }
}

// MARK: - Wrapper

struct NetworkAssistantWrapperView: View {
    var focusDevice: ThreadDevice? = nil

    var body: some View {
        if #available(iOS 26, *) {
            NetworkAssistantView(focusDevice: focusDevice)
        } else {
            List {
                Section {
                    VStack(spacing: 12) {
                        Image(systemName: "apple.intelligence").font(.largeTitle).foregroundStyle(.secondary)
                        Text("iOS 26 Required").font(.headline)
                        Text("Network Assistant requires iOS 26 or later with Apple Intelligence.")
                            .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 24)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Network Assistant")
        }
    }
}
