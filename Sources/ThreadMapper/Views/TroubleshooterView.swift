import SwiftUI

struct TroubleshooterView: View {
    let device: ThreadDevice
    let problem: Problem

    @Environment(\.dismiss) private var dismiss
    @State private var stepIndex = 0
    @State private var resolved = false

    enum Problem: Identifiable {
        case offline
        case weakSignal
        var id: Self { self }
    }

    private struct Step {
        let instruction: String
        let hint: String?
    }

    private var steps: [Step] {
        if problem == .weakSignal { return weakSteps }
        if device.isBorderRouter { return borderRouterSteps }
        if device.isRouter       { return routerSteps }
        return endDeviceSteps
    }

    var body: some View {
        NavigationStack {
            if resolved {
                resolvedView
            } else {
                stepView
            }
        }
    }

    // MARK: - Step view

    private var stepView: some View {
        VStack(spacing: 0) {
            // Header card
            VStack(spacing: 8) {
                Image(systemName: problem == .offline ? "network.slash" : "wifi.exclamationmark")
                    .font(.system(size: 36))
                    .foregroundStyle(problem == .offline ? Color.red : Color.orange)
                    .padding(.top, 24)

                Text(device.name)
                    .font(.title3.weight(.semibold))
                Text(problem == .offline ? "Device is offline" : "Signal is weak")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                // Step dots
                HStack(spacing: 6) {
                    ForEach(0..<steps.count, id: \.self) { i in
                        Circle()
                            .fill(i == stepIndex ? Color.accentColor : Color.secondary.opacity(0.3))
                            .frame(width: i == stepIndex ? 8 : 6, height: i == stepIndex ? 8 : 6)
                            .animation(.easeInOut(duration: 0.2), value: stepIndex)
                    }
                }
                .padding(.top, 4)
                .padding(.bottom, 8)
            }
            .frame(maxWidth: .infinity)
            .background(.ultraThinMaterial)

            Divider()

            // Step content
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack {
                        Text("Step \(stepIndex + 1) of \(steps.count)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                            .tracking(0.5)
                        Spacer()
                    }

                    Text(steps[stepIndex].instruction)
                        .font(.body)
                        .fixedSize(horizontal: false, vertical: true)

                    if let hint = steps[stepIndex].hint {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "info.circle")
                                .foregroundStyle(.blue)
                                .imageScale(.small)
                            Text(hint)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(10)
                        .background(Color.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                    }
                }
                .padding(24)
            }

            Spacer(minLength: 0)
            Divider()

            // Action buttons
            VStack(spacing: 10) {
                Button {
                    withAnimation { resolved = true }
                } label: {
                    Label("This fixed it", systemImage: "checkmark")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)

                Button {
                    withAnimation {
                        if stepIndex + 1 < steps.count {
                            stepIndex += 1
                        }
                    }
                } label: {
                    Group {
                        if stepIndex + 1 < steps.count {
                            Label("Still broken — next step", systemImage: "arrow.right")
                        } else {
                            Text("No more steps")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                }
                .buttonStyle(.bordered)
                .disabled(stepIndex + 1 >= steps.count)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .navigationTitle("Troubleshooter")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") { dismiss() }
            }
        }
    }

    // MARK: - Resolved view

    private var resolvedView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.green)
            Text("Great!")
                .font(.title.weight(.bold))
            Text("\(device.name) should be back online shortly. If it doesn't reappear in the next minute, try restarting the app.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
            Button("Done") { dismiss() }
                .buttonStyle(.borderedProminent)
                .padding(.bottom, 32)
        }
        .navigationTitle("Troubleshooter")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Step definitions

    private var endDeviceSteps: [Step] { [
        Step(
            instruction: "Check that the device has power. Replace the battery if it's battery-powered, or confirm the power cable is firmly connected.",
            hint: "Battery-powered Thread devices typically last 1–2 years on a coin cell."
        ),
        Step(
            instruction: "Move the device temporarily closer to your HomePod mini or Apple TV to rule out a range issue.",
            hint: "Thread has a range of roughly 10–30 metres indoors, less through concrete walls."
        ),
        Step(
            instruction: "Open the Apple Home app and check if the device shows as 'Not Responding' there too. If so, the issue is with HomeKit — not ThreadMapper.",
            hint: nil
        ),
        Step(
            instruction: "In the Apple Home app, long-press the device tile, scroll to the bottom, and tap Remove Accessory. Then re-add it as a new accessory.",
            hint: "This forces the device to re-negotiate its Thread mesh path."
        ),
        Step(
            instruction: "Factory reset the device using its hardware button (check the manufacturer's instructions), then pair it again fresh in the Home app.",
            hint: "As a last resort, a factory reset clears any corrupted Thread credentials."
        ),
    ] }

    private var routerSteps: [Step] { [
        Step(
            instruction: "Check that the device is plugged in and powered on. Thread router devices need a constant power supply — battery devices can't act as routers.",
            hint: nil
        ),
        Step(
            instruction: "Unplug the device from power, wait 30 seconds, then plug it back in.",
            hint: "This forces the device to re-join the Thread mesh from scratch."
        ),
        Step(
            instruction: "Check your border router (HomePod mini or Apple TV) is online. If it's offline, that's the root cause.",
            hint: nil
        ),
        Step(
            instruction: "Remove and re-add the device in the Apple Home app to clear any stale Thread credentials.",
            hint: nil
        ),
        Step(
            instruction: "Factory reset the device and pair it again in the Home app.",
            hint: nil
        ),
    ] }

    private var borderRouterSteps: [Step] { [
        Step(
            instruction: "Unplug your HomePod mini or Apple TV, wait 30 seconds, then plug it back in. This is the most effective first step.",
            hint: "All Thread devices on your network depend on the border router — restarting it affects everything."
        ),
        Step(
            instruction: "Make sure the device is connected to your Wi-Fi network. Open Settings → Wi-Fi and confirm the network looks healthy.",
            hint: "Border routers need a stable Wi-Fi connection to bridge Thread and the internet."
        ),
        Step(
            instruction: "Check for software updates: open the Home app, tap the Home icon (top left), and look for Software Update.",
            hint: "Apple regularly ships Thread firmware improvements via HomePod and Apple TV updates."
        ),
        Step(
            instruction: "Remove the device from the Home app (tap the device → scroll down → Remove from Home), then set it up again as a new home hub.",
            hint: "This is a significant step — all automations tied to this hub may need to be reconfigured."
        ),
        Step(
            instruction: "If none of the above work, contact Apple Support. Your HomePod mini or Apple TV may have a hardware issue.",
            hint: nil
        ),
    ] }

    private var weakSteps: [Step] { [
        Step(
            instruction: "Move this device 1–2 metres closer to your HomePod mini, HomePod, or Apple TV and see if signal improves.",
            hint: "Even a small reduction in distance can significantly improve Thread signal."
        ),
        Step(
            instruction: "Check for physical obstructions between this device and the nearest border router. Concrete walls, metal appliances, and large mirrors are the biggest signal killers.",
            hint: nil
        ),
        Step(
            instruction: "Add a Thread-capable plug (like Eve Energy or Nanoleaf bulb) between this device and the border router. Plugged-in Thread devices automatically extend the mesh.",
            hint: "Thread is a mesh network — each always-powered device acts as a signal repeater."
        ),
        Step(
            instruction: "Reposition your HomePod mini or Apple TV to a more central location in your home so it's equidistant from all devices.",
            hint: "The border router's location has the biggest impact on overall mesh quality."
        ),
        Step(
            instruction: "If signal remains weak after all the above, the device's physical environment may simply be challenging for 2.4 GHz radio. Consider the device's placement permanent and focus on adding intermediate routers.",
            hint: nil
        ),
    ] }
}
