@preconcurrency import BackgroundTasks
import HomeKit
import OSLog
import UserNotifications

private let logger = Logger(subsystem: "com.tintronixlab.ThreadMapper", category: "background")

enum BackgroundRefreshHandler {
    static let refreshTaskID  = "com.tintronixlab.ThreadMapper.bgrefresh"
    static let watchdogTaskID = "com.tintronixlab.ThreadMapper.healthwatch"
    // Legacy alias kept so schedule() call in ContentView continues to work
    static let taskID = refreshTaskID

    static func register() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: refreshTaskID, using: .main) { task in
            MainActor.assumeIsolated {
                guard let refreshTask = task as? BGAppRefreshTask else {
                    logger.error("Unexpected task type for \(refreshTaskID, privacy: .public); marking complete")
                    task.setTaskCompleted(success: false)
                    return
                }
                handleRefresh(task: refreshTask)
            }
        }
        BGTaskScheduler.shared.register(forTaskWithIdentifier: watchdogTaskID, using: .main) { task in
            MainActor.assumeIsolated {
                guard let processingTask = task as? BGProcessingTask else {
                    task.setTaskCompleted(success: false)
                    return
                }
                handleHealthWatch(task: processingTask)
            }
        }
    }

    static func schedule() {
        let request = BGAppRefreshTaskRequest(identifier: refreshTaskID)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            logger.error("BGAppRefreshTask submit failed: \(error.localizedDescription)")
        }

        let watchdog = BGProcessingTaskRequest(identifier: watchdogTaskID)
        watchdog.earliestBeginDate = Date(timeIntervalSinceNow: 60 * 60)
        watchdog.requiresNetworkConnectivity = false
        watchdog.requiresExternalPower = false
        do {
            try BGTaskScheduler.shared.submit(watchdog)
        } catch {
            logger.error("BGProcessingTask submit failed: \(error.localizedDescription)")
        }
    }

    @MainActor
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

    @MainActor
    private static func handleHealthWatch(task: BGProcessingTask) {
        schedule()

        let watcher = HealthWatcher()
        let work = Task {
            await watcher.run()
            task.setTaskCompleted(success: true)
        }
        task.expirationHandler = {
            work.cancel()
            task.setTaskCompleted(success: false)
        }
    }
}

// MARK: - Health Watchdog (NF-4)
// Computes a lightweight grade from HM reachability; fires a notification if
// the grade has dropped since the last foreground snapshot.

// `@MainActor`, not `@unchecked Sendable`: this owns an `HMHomeManager` created
// on the main actor and set as its own delegate, so HomeKit calls back on the
// main queue. `run()`/`computeAndNotifyIfNeeded()` were `nonisolated async` and
// therefore ran on the cooperative pool, reading `manager.homes` and
// `acc.isReachable` concurrently with those main-queue callbacks. The polling
// loop below suspends at `Task.sleep`, so main-actor isolation doesn't block the
// main thread during the BGTask window.
@MainActor
private final class HealthWatcher: NSObject, HMHomeManagerDelegate {
    private static let lastGradeKey = "bgLastGrade"
    private let manager = HMHomeManager()

    override init() {
        super.init()
        manager.delegate = self
    }

    func run() async {
        for _ in 0..<16 {
            if !manager.homes.isEmpty { break }
            try? await Task.sleep(for: .milliseconds(500))
        }
        await computeAndNotifyIfNeeded()
    }

    nonisolated func homeManagerDidUpdateHomes(_ manager: HMHomeManager) {}

    private func computeAndNotifyIfNeeded() async {
        var total = 0
        var offline = 0
        for home in manager.homes {
            for acc in home.accessories {
                total += 1
                if !acc.isReachable { offline += 1 }
            }
        }

        guard total > 0 else { return }

        let score = max(0, 100 - offline * 12)
        let grade: String
        switch score {
        case 90...:  grade = "A"
        case 75..<90: grade = "B"
        case 60..<75: grade = "C"
        case 40..<60: grade = "D"
        default:      grade = "F"
        }

        let gradeOrder = ["A": 0, "B": 1, "C": 2, "D": 3, "F": 4]
        let lastGrade = UserDefaults.standard.string(forKey: Self.lastGradeKey) ?? "A"
        let currentRank = gradeOrder[grade] ?? 4
        let lastRank    = gradeOrder[lastGrade] ?? 0

        UserDefaults.standard.set(grade, forKey: Self.lastGradeKey)

        if currentRank > lastRank {
            await HealthWatcher.fireGradeDropNotification(from: lastGrade, to: grade, offlineCount: offline)
        }
    }

    @MainActor
    static func fireGradeDropNotification(from old: String, to new: String, offlineCount: Int) async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        guard settings.authorizationStatus == .authorized else { return }

        let content = UNMutableNotificationContent()
        content.title = "Network Health Dropped"
        content.body = offlineCount > 0
            ? "Your mesh grade fell from \(old) to \(new) — \(offlineCount) device\(offlineCount == 1 ? "" : "s") offline."
            : "Your mesh grade fell from \(old) to \(new). Open ThreadMapper to investigate."
        content.sound = .default
        content.categoryIdentifier = "HEALTH_DROP"

        let request = UNNotificationRequest(identifier: "health-drop-\(Date().timeIntervalSince1970)",
                                            content: content, trigger: nil)
        try? await UNUserNotificationCenter.current().add(request)
        logger.info("Background health watchdog fired grade-drop notification: \(old)→\(new)")
    }
}

// MARK: - Reachability checker

// Checks HMAccessory.isReachable for all accessories and fires
// offline/online notifications for state changes since last run.
// `@MainActor` for the same reason as `HealthWatcher` — see the note there.
@MainActor
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

    nonisolated func homeManagerDidUpdateHomes(_ manager: HMHomeManager) {}

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
            let room = rooms[key]
            let wasReachable = previous[key] ?? true
            // Already on the main actor — the former `MainActor.run` hop is gone.
            if !reachable && wasReachable {
                NotificationService.shared.notifyDeviceOffline(name, room: room, deviceID: uuid)
            } else if reachable && !wasReachable {
                NotificationService.shared.clearOfflineNotification(for: uuid)
            }
        }

        AppGroupStore.writeDeviceStates(current)
    }
}
