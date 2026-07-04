import BackgroundTasks
import HomeKit

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
        try? BGTaskScheduler.shared.submit(request)
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

        for home in manager.homes {
            for acc in home.accessories {
                current[acc.name] = acc.isReachable
                if let room = acc.room { rooms[acc.name] = room.name }
            }
        }

        for (name, reachable) in current {
            let wasReachable = previous[name] ?? true
            if !reachable && wasReachable {
                NotificationService.shared.notifyDeviceOffline(name, room: rooms[name])
            } else if reachable && !wasReachable {
                NotificationService.shared.clearOfflineNotification(for: name)
            }
        }

        AppGroupStore.writeDeviceStates(current)
    }
}
