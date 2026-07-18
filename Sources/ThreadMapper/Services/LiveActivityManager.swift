@preconcurrency import ActivityKit
import Foundation

@MainActor
final class LiveActivityManager {
    static let shared = LiveActivityManager()
    private var currentActivity: Activity<ThreadNetworkActivityAttributes>?

    private let appGroupDefaults = UserDefaults(suiteName: "group.com.tintronixlab.ThreadMapper")
    private let dismissedKey = "liveActivityUserDismissed"

    private init() {}

    // MARK: - Active check

    private var hasActiveActivity: Bool {
        guard let state = currentActivity?.activityState else { return false }
        if state == .ended || state == .dismissed {
            currentActivity = nil
            return false
        }
        return state == .active || state == .stale
    }

    // Whether the user explicitly dismissed via the Dynamic Island button.
    // Suppresses re-creation until all devices come back online.
    private var isUserDismissed: Bool {
        appGroupDefaults?.bool(forKey: dismissedKey) ?? false
    }

    private func clearUserDismissed() {
        appGroupDefaults?.removeObject(forKey: dismissedKey)
    }

    // MARK: - Public API

    /// Start or update the Live Activity when a device goes offline.
    func alertDeviceOffline(name: String, grade: String, score: Int, deviceCount: Int, offlineCount: Int) {
        guard !isUserDismissed else { return }
        let message = offlineCount == 1 ? "\(name) is offline" : "\(offlineCount) devices offline"
        let state = ThreadNetworkActivityAttributes.ContentState(
            grade: grade, score: score, deviceCount: deviceCount,
            offlineCount: offlineCount, isScanning: false,
            alertMessage: message
        )
        if hasActiveActivity {
            Task { @MainActor in
                await self.currentActivity?.update(
                    .init(state: state, staleDate: .now.addingTimeInterval(7200))
                )
            }
        } else {
            guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
            let attrs = ThreadNetworkActivityAttributes(networkName: "Thread Network")
            currentActivity = try? Activity.request(
                attributes: attrs,
                content: .init(state: state, staleDate: .now.addingTimeInterval(7200))
            )
        }
    }

    /// Update the Live Activity while some devices are still offline.
    func updateStatus(grade: String, score: Int, deviceCount: Int, offlineCount: Int) {
        guard hasActiveActivity else { return }
        let message = offlineCount > 0
            ? String(localized: "\(offlineCount) \(offlineCount == 1 ? "device" : "devices") offline")
            : nil
        let state = ThreadNetworkActivityAttributes.ContentState(
            grade: grade, score: score, deviceCount: deviceCount,
            offlineCount: offlineCount, isScanning: false, alertMessage: message
        )
        Task { @MainActor in
            await self.currentActivity?.update(
                .init(state: state, staleDate: .now.addingTimeInterval(7200))
            )
        }
    }

    /// End the Live Activity with an "all back online" message, then dismiss after 5 s.
    func endIfAllOnline(grade: String, score: Int, deviceCount: Int) {
        clearUserDismissed()
        guard currentActivity != nil else { return }
        let state = ThreadNetworkActivityAttributes.ContentState(
            grade: grade, score: score, deviceCount: deviceCount,
            offlineCount: 0, isScanning: false, alertMessage: "All devices back online"
        )
        Task { @MainActor in
            await self.currentActivity?.end(
                .init(state: state, staleDate: nil),
                dismissalPolicy: .after(.now.addingTimeInterval(5))
            )
            self.currentActivity = nil
        }
    }

    /// Immediately dismiss the Live Activity (e.g. tapped the dismiss button).
    func endNow() {
        guard currentActivity != nil else { return }
        Task { @MainActor in
            await self.currentActivity?.end(nil, dismissalPolicy: .immediate)
            self.currentActivity = nil
        }
    }
}
