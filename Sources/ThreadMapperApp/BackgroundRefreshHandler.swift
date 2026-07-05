import BackgroundTasks
import HomeKit
import OSLog

private let logger = Logger(subsystem: "com.tintronixlab.ThreadMapper", category: "background")

enum BackgroundRefreshHandler {
    static let taskID = "com.tintronixlab.ThreadMapper.bgrefresh"

    static func register() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: taskID, using: .main) { task in
            handleRefresh(task: task as! BGAppRefreshTask)
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
        let previous = AppGroupStore.readDeviceStates()
        var current: [String: Bool] = [:]
        var rooms: [String: String] = [:]

        // Collect current state keyed by name (for AppGroupStore) and by UUID (for notifications)
        var uuidByName: [String: UUID] = [:]
        for home in manager.homes {
            for acc in home.accessories {
                current[acc.name] = acc.isReachable
                uuidByName[acc.name] = acc.uniqueIdentifier
                if let room = acc.room { rooms[acc.name] = room.name }
            }
        }

        for (name, reachable) in current {
            guard let uuid = uuidByName[name] else { continue }
            let wasReachable = previous[name] ?? true
            if !reachable && wasReachable {
                NotificationService.shared.notifyDeviceOffline(name, room: rooms[name], deviceID: uuid)
            } else if reachable && !wasReachable {
                NotificationService.shared.clearOfflineNotification(for: uuid)
            }
        }

        AppGroupStore.writeDeviceStates(current)
    }
}
