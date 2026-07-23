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

    /// Pushes live Guided Survey state to the watch remote. Sent only when the
    /// watch is reachable (its app is foreground) — guided control is a live,
    /// both-apps-active interaction, so there's no need to queue it.
    func sendGuidedState(active: Bool, room: String?, recording: Bool,
                         elapsed: Int, completed: Int, total: Int) {
        guard WCSession.default.activationState == .activated,
              WCSession.default.isReachable else { return }
        var message: [String: Any] = [
            "type": "guided",
            "active": active,
            "recording": recording,
            "elapsed": elapsed,
            "completed": completed,
            "total": total
        ]
        if let room { message["room"] = room }
        WCSession.default.sendMessage(message, replyHandler: nil, errorHandler: { _ in })
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

    /// Watch → phone Guided Survey commands (start / done / skip).
    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        guard message["type"] as? String == "guidedCmd",
              let command = message["cmd"] as? String else { return }
        Task { @MainActor in GuidedSurveyBridge.shared.handleCommand(command) }
    }
}
