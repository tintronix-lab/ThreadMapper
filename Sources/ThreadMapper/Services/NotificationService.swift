import UserNotifications
import Foundation
import Observation

@Observable
final class NotificationService {
    static let shared = NotificationService()

    private(set) var isAuthorized = false

    private init() {
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
        content.title = "Thread Device Offline"
        content.body = room != nil ? "\(name) (\(room!)) is unreachable" : "\(name) is unreachable"
        content.sound = .default
        content.categoryIdentifier = "DEVICE_OFFLINE"
        schedule(content, id: "offline-\(deviceID.uuidString)")
    }

    func clearOfflineNotification(for deviceID: UUID) {
        let id = "offline-\(deviceID.uuidString)"
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [id])
    }

    func notifyTopologyChange(joined: [String], left: [String]) {
        guard isAuthorized, !joined.isEmpty || !left.isEmpty,
              UserDefaults.standard.object(forKey: "notifyTopology") as? Bool ?? true,
              !isInQuietHours() else { return }
        let content = UNMutableNotificationContent()
        content.title = "Thread Network Changed"
        var parts: [String] = []
        if !joined.isEmpty { parts.append("\(joined.joined(separator: ", ")) joined") }
        if !left.isEmpty   { parts.append("\(left.joined(separator: ", ")) left") }
        content.body = parts.joined(separator: " · ")
        content.sound = .default
        schedule(content, id: "topology-\(Int(Date().timeIntervalSince1970))")
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
    static func isInQuietHours(hour: Int, start: Int, end: Int) -> Bool {
        if start <= end {
            return hour >= start && hour < end
        }
        return hour >= start || hour < end   // wraps midnight
    }

    func scheduleWeeklyReport() {
        guard isAuthorized else { return }
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["weekly-report"])
        let content = UNMutableNotificationContent()
        content.title = "Your Weekly Thread Report"
        content.body = "Tap to see how your network performed this week."
        content.sound = .default
        var dc = DateComponents()
        dc.weekday = 1  // Sunday
        dc.hour = 9
        dc.minute = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: dc, repeats: true)
        center.add(UNNotificationRequest(identifier: "weekly-report", content: content, trigger: trigger))
    }

    private func schedule(_ content: UNMutableNotificationContent, id: String) {
        let request = UNNotificationRequest(identifier: id, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
