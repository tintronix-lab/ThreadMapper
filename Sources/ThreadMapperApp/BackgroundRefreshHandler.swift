import BackgroundTasks
import HomeKit
import OSLog

private let logger = Logger(subsystem: "com.tintronixlab.ThreadMapper", category: "background")

enum BackgroundRefreshHandler {
    static let taskID = "com.tintronixlab.ThreadMapper.bgrefresh"

    static func register() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: taskID, using: .main) { task in
            guard let refreshTask = task as? BGAppRefreshTask else {
                logger.error("Unexpected task type for \(taskID, privacy: .public); marking complete")
                task.setTaskCompleted(success: false)
                return
            }
            handleRefresh(task: refreshTask)
        }
    }

    static func schedule() {
        let request = BGAppRefreshTaskRequest(identifier: taskID)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            logger.error("BGTaskScheduler submit failed: \(error.localizedDescription)")
        }
    }

    private static func handleRefresh(task: BGAppRefreshTask) {
        schedule()

        let checker = ReachabilityChecker()
        let work = Task {
            await checker.run()
            task.setTaskCompleted(success: true)
        }
        task.expirationHandler = {
            work.cancel()
            task.setTaskCompleted(success: false)
        }
    }
}

// Checks HMAccessory.isReachable for all accessories and fires
// offline/online notifications for state changes since last run.
private final class ReachabilityChecker: NSObject, HMHomeManagerDelegate {
    private let manager = HMHomeManager()

    override init() {
        super.init()
        manager.delegate = self
    }

    func run() async {
        // Poll until HomeKit reports at least one home (max 8 s)
        for _ in 0..<16 {
            if !manager.homes.isEmpty { break }
            try? await Task.sleep(for: .milliseconds(500))
        }
        await checkAndNotify()
    }

    func homeManagerDidUpdateHomes(_ manager: HMHomeManager) {}

    private func checkAndNotify() async {
        // State is keyed by device uniqueIdentifier (uuidString), matching the
        // foreground poll loop — duplicate names never collide and a rename never
        // reads as a device going offline.
        let previous = AppGroupStore.readDeviceStates()
        var current: [String: Bool] = [:]
        var names: [String: String] = [:]
        var rooms: [String: String] = [:]

        for home in manager.homes {
            for acc in home.accessories {
                let key = acc.uniqueIdentifier.uuidString
                current[key] = acc.isReachable
                names[key] = acc.name
                if let room = acc.room { rooms[key] = room.name }
            }
        }

        for (key, reachable) in current {
            guard let uuid = UUID(uuidString: key) else { continue }
            let name = names[key] ?? "Device"
            let wasReachable = previous[key] ?? true
            await MainActor.run {
                if !reachable && wasReachable {
                    NotificationService.shared.notifyDeviceOffline(name, room: rooms[key], deviceID: uuid)
                } else if reachable && !wasReachable {
                    NotificationService.shared.clearOfflineNotification(for: uuid)
                }
            }
        }

        AppGroupStore.writeDeviceStates(current)
    }
}
