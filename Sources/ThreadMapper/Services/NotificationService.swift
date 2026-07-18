import UserNotifications
import Foundation
import Observation

enum NotificationDeepLink: Equatable {
    case deviceDetail(UUID)
    case dashboard
    case activity
}

@MainActor
@Observable
final class NotificationService: NSObject {
    static let shared = NotificationService()

    private(set) var isAuthorized = false
    var pendingDeepLink: NotificationDeepLink? = nil

    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
        Task { await refreshAuthStatus() }
    }

    func requestAuthorization() async {
        do {
            isAuthorized = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            isAuthorized = false
        }
    }

    func refreshAuthStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        isAuthorized = settings.authorizationStatus == .authorized
    }

    func notifyDeviceOffline(_ name: String, room: String?, deviceID: UUID) {
        guard isAuthorized,
              UserDefaults.standard.object(forKey: "notifyOffline") as? Bool ?? true,
              !isInQuietHours() else { return }
        let content = UNMutableNotificationContent()
        content.title = String(localized: "Thread Device Offline")
        content.body = room.map { String(localized: "\(name) (\($0)) is unreachable") } ?? String(localized: "\(name) is unreachable")
        content.sound = .default
        content.categoryIdentifier = "DEVICE_OFFLINE"
        schedule(content, id: "offline-\(deviceID.uuidString)")
    }

    func clearOfflineNotification(for deviceID: UUID) {
        let id = "offline-\(deviceID.uuidString)"
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [id])
    }

    func notifyHealthDrop(from oldGrade: String, to newGrade: String) {
        guard isAuthorized,
              UserDefaults.standard.object(forKey: "notifyHealthDrop") as? Bool ?? true,
              !isInQuietHours() else { return }
        let content = UNMutableNotificationContent()
        content.title = String(localized: "Mesh Health Dropped")
        content.body = String(localized: "Your Thread network grade fell from \(oldGrade) to \(newGrade). Open ThreadMapper to diagnose.")
        content.sound = .default
        content.categoryIdentifier = "HEALTH_DROP"
        schedule(content, id: "health-drop-\(Int(Date().timeIntervalSince1970))")
    }

    func notifyGradeImproved(from oldGrade: String, to newGrade: String) {
        guard isAuthorized,
              UserDefaults.standard.object(forKey: "notifyHealthDrop") as? Bool ?? true,
              !isInQuietHours() else { return }
        let content = UNMutableNotificationContent()
        content.title = String(localized: "Mesh Health Improved")
        content.body = newGrade == "A"
            ? String(localized: "Your Thread network is back to an excellent grade \(newGrade)!")
            : String(localized: "Your Thread network improved from grade \(oldGrade) to \(newGrade).")
        content.sound = .default
        content.categoryIdentifier = "HEALTH_DROP"
        schedule(content, id: "health-improve-\(Int(Date().timeIntervalSince1970))")
    }

    func notifyAllDevicesOnline(count: Int) {
        guard isAuthorized,
              UserDefaults.standard.object(forKey: "notifyOffline") as? Bool ?? true,
              !isInQuietHours() else { return }
        let content = UNMutableNotificationContent()
        content.title = String(localized: "All Devices Back Online")
        content.body = String(localized: "All \(count) Thread devices are online and your mesh is fully connected.")
        content.sound = .default
        content.categoryIdentifier = "DEVICE_OFFLINE"
        schedule(content, id: "all-online-\(Int(Date().timeIntervalSince1970))")
    }

    func notifyTopologyChange(joined: [String], left: [String]) {
        guard isAuthorized, !joined.isEmpty || !left.isEmpty,
              UserDefaults.standard.object(forKey: "notifyTopology") as? Bool ?? true,
              !isInQuietHours() else { return }
        let content = UNMutableNotificationContent()
        content.title = String(localized: "Thread Network Changed")
        var parts: [String] = []
        if !joined.isEmpty { parts.append(String(localized: "\(joined.joined(separator: ", ")) joined")) }
        if !left.isEmpty   { parts.append(String(localized: "\(left.joined(separator: ", ")) left")) }
        content.body = parts.joined(separator: " · ")
        content.sound = .default
        schedule(content, id: "topology-\(Int(Date().timeIntervalSince1970))")
    }

    func notifyFirstSeenDevice(name: String, id: UUID) {
        guard isAuthorized,
              UserDefaults.standard.object(forKey: "notifyNewDevice") as? Bool ?? true,
              !isInQuietHours() else { return }
        let content = UNMutableNotificationContent()
        content.title = String(localized: "New Thread Device Detected")
        content.body = String(localized: "\(name) has joined your mesh for the first time.")
        content.sound = .default
        content.userInfo = ["deepLink": "device/\(id.uuidString)"]
        schedule(content, id: "first-seen-\(id.uuidString)")
    }

    func notifyProactiveInsight(headline: String, detail: String) {
        guard isAuthorized,
              UserDefaults.standard.object(forKey: "notifyProactiveAI") as? Bool ?? true,
              !isInQuietHours() else { return }
        let content = UNMutableNotificationContent()
        content.title = String(localized: "AI Network Insight")
        content.body = "\(headline). \(detail)"
        content.sound = .default
        content.categoryIdentifier = "AI_INSIGHT"
        schedule(content, id: "ai-insight-\(Int(Date().timeIntervalSince1970))")
    }

    func updateBadge(_ count: Int) {
        guard isAuthorized else { return }
        Task {
            try? await UNUserNotificationCenter.current().setBadgeCount(count)
        }
    }

    // MARK: - Quiet Hours

    // Returns true if the current time falls within the user-configured quiet window.
    // Stored as hours (0–23) in UserDefaults: "quietHoursEnabled", "quietHoursStart", "quietHoursEnd".
    func isInQuietHours() -> Bool {
        guard UserDefaults.standard.bool(forKey: "quietHoursEnabled") else { return false }
        let startHour = UserDefaults.standard.integer(forKey: "quietHoursStart")
        let endHour   = UserDefaults.standard.integer(forKey: "quietHoursEnd")
        let now = Calendar.current.component(.hour, from: Date())
        return Self.isInQuietHours(hour: now, start: startHour, end: endHour)
    }

    /// Pure window check: start inclusive, end exclusive; a start > end window
    /// wraps midnight (e.g. 22–7). Extracted so the wrap logic is unit-testable.
    nonisolated static func isInQuietHours(hour: Int, start: Int, end: Int) -> Bool {
        if start <= end {
            return hour >= start && hour < end
        }
        return hour >= start || hour < end   // wraps midnight
    }

    func scheduleWeeklyReport() {
        guard isAuthorized,
              UserDefaults.standard.object(forKey: "notifyWeeklyReport") as? Bool ?? true else { return }
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["weekly-report"])
        let content = UNMutableNotificationContent()
        content.title = String(localized: "Your Weekly Thread Report")
        content.body = String(localized: "Tap to see how your network performed this week.")
        content.sound = .default
        var dc = DateComponents()
        dc.weekday = 1  // Sunday
        dc.hour = 9
        dc.minute = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: dc, repeats: true)
        center.add(UNNotificationRequest(identifier: "weekly-report", content: content, trigger: trigger))
    }

    func scheduleWeeklyReportWithAIHeadline(
        devices: [ThreadDevice],
        health: NetworkHealthScore,
        historyEntries: [HealthHistoryStore.Entry]
    ) async {
        guard isAuthorized,
              UserDefaults.standard.object(forKey: "notifyWeeklyReport") as? Bool ?? true else { return }
        guard #available(iOS 26, *) else { scheduleWeeklyReport(); return }
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["weekly-report"])
        let content = UNMutableNotificationContent()
        content.title = String(localized: "Your Weekly Thread Report")
        content.sound = .default
        do {
            let headline = try await AINetworkAnalyzer.weeklyDigestHeadline(
                devices: devices,
                health: health,
                historyEntries: historyEntries
            )
            content.body = headline.isEmpty ? String(localized: "Tap to see how your network performed this week.") : headline
        } catch {
            content.body = String(localized: "Tap to see how your network performed this week.")
        }
        var dc = DateComponents()
        dc.weekday = 1
        dc.hour = 9
        dc.minute = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: dc, repeats: true)
        try? await center.add(UNNotificationRequest(identifier: "weekly-report", content: content, trigger: trigger))
    }

    private func schedule(_ content: UNMutableNotificationContent, id: String) {
        let request = UNNotificationRequest(identifier: id, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationService: UNUserNotificationCenterDelegate {
    // Called when user taps a notification while app is in background or closed.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let id = response.notification.request.identifier
        Task { @MainActor [self] in
            if id.hasPrefix("offline-") {
                let uuidStr = String(id.dropFirst("offline-".count))
                if let uuid = UUID(uuidString: uuidStr) {
                    pendingDeepLink = .deviceDetail(uuid)
                } else {
                    pendingDeepLink = .dashboard
                }
            } else if id.hasPrefix("health-drop-") {
                pendingDeepLink = .dashboard
            } else if id.hasPrefix("topology-") {
                pendingDeepLink = .activity
            } else if id == "weekly-report" {
                pendingDeepLink = .activity
            }
        }
        completionHandler()
    }

    // Show notifications as banners even when app is in foreground.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }
}
