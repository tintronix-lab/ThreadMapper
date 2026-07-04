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

    func notifyDeviceOffline(_ name: String, room: String?) {
        guard isAuthorized else { return }
        let content = UNMutableNotificationContent()
        content.title = "Thread Device Offline"
        content.body = room != nil ? "\(name) (\(room!)) is unreachable" : "\(name) is unreachable"
        content.sound = .default
        content.categoryIdentifier = "DEVICE_OFFLINE"
        schedule(content, id: "offline-\(name)")
    }

    func clearOfflineNotification(for name: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["offline-\(name)"])
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: ["offline-\(name)"])
    }

    func notifyTopologyChange(joined: [String], left: [String]) {
        guard isAuthorized, !joined.isEmpty || !left.isEmpty else { return }
        let content = UNMutableNotificationContent()
        content.title = "Thread Network Changed"
        var parts: [String] = []
        if !joined.isEmpty { parts.append("\(joined.joined(separator: ", ")) joined") }
        if !left.isEmpty   { parts.append("\(left.joined(separator: ", ")) left") }
        content.body = parts.joined(separator: " · ")
        content.sound = .default
        schedule(content, id: "topology-\(Int(Date().timeIntervalSince1970))")
    }

    private func schedule(_ content: UNMutableNotificationContent, id: String) {
        let request = UNNotificationRequest(identifier: id, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
