import WatchConnectivity

/// Pushes live mesh health snapshots to the paired Apple Watch.
/// Uses `updateApplicationContext` so the Watch receives the latest state
/// on next wakeup even if it wasn't reachable at the time of the update.
@MainActor
final class WatchConnectivityManager: NSObject {
    static let shared = WatchConnectivityManager()

    override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func send(snapshot: WidgetSnapshot, borderRouterOffline: Bool) {
        guard WCSession.default.activationState == .activated,
              WCSession.default.isWatchAppInstalled else { return }
        let context: [String: Any] = [
            "grade": snapshot.grade,
            "score": snapshot.score,
            "deviceCount": snapshot.deviceCount,
            "offlineCount": snapshot.offlineCount,
            "brOffline": borderRouterOffline,
            "ts": snapshot.updatedAt.timeIntervalSince1970
        ]
        try? WCSession.default.updateApplicationContext(context)
    }
}

extension WatchConnectivityManager: WCSessionDelegate {
    nonisolated func session(_ session: WCSession,
                             activationDidCompleteWith state: WCSessionActivationState,
                             error: Error?) {}
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}
    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        WCSession.default.activate()
    }
}
