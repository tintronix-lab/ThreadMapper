import WatchConnectivity
import WatchKit

/// Receives live health snapshots from the paired iPhone via WatchConnectivity.
/// Plays a haptic when a border router transitions to offline.
@MainActor
final class WatchConnectivityStore: NSObject, ObservableObject {
    @Published var grade: String = "—"
    @Published var score: Int = 0
    @Published var deviceCount: Int = 0
    @Published var offlineCount: Int = 0
    @Published var borderRouterOffline: Bool = false
    @Published var lastUpdated: Date?

    // Guided Survey remote state (mirrored from the iPhone).
    @Published var guidedActive: Bool = false
    @Published var guidedRoom: String?
    @Published var guidedRecording: Bool = false
    @Published var guidedElapsed: Int = 0
    @Published var guidedCompleted: Int = 0
    @Published var guidedTotal: Int = 0

    override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    /// Send a Guided Survey command (start / done / skip) to the iPhone. Only
    /// works while the phone app is reachable (foreground), which the remote
    /// requires anyway.
    func sendGuidedCommand(_ command: String) {
        guard WCSession.default.activationState == .activated,
              WCSession.default.isReachable else { return }
        WCSession.default.sendMessage(["type": "guidedCmd", "cmd": command],
                                      replyHandler: nil, errorHandler: nil)
        WKInterfaceDevice.current().play(.click)
    }

    fileprivate func applyGuided(active: Bool, room: String?, recording: Bool,
                                 elapsed: Int, completed: Int, total: Int) {
        guidedActive = active
        guidedRoom = room
        guidedRecording = recording
        guidedElapsed = elapsed
        guidedCompleted = completed
        guidedTotal = total
    }

    // All parameters are Sendable primitives — safe to pass across actor boundaries.
    fileprivate func apply(grade: String?, score: Int?, deviceCount: Int?,
                           offlineCount: Int?, brOffline: Bool?, ts: TimeInterval?) {
        let prevBROffline = borderRouterOffline
        if let g = grade { self.grade = g }
        if let s = score { self.score = s }
        if let d = deviceCount { self.deviceCount = d }
        if let o = offlineCount { self.offlineCount = o }
        self.borderRouterOffline = brOffline ?? false
        if let t = ts { self.lastUpdated = Date(timeIntervalSince1970: t) }
        if self.borderRouterOffline && !prevBROffline {
            WKInterfaceDevice.current().play(.notification)
        }
    }
}

extension WatchConnectivityStore: WCSessionDelegate {
    nonisolated func session(_ session: WCSession,
                             activationDidCompleteWith state: WCSessionActivationState,
                             error: Error?) {
        let ctx = WCSession.default.receivedApplicationContext
        guard !ctx.isEmpty else { return }
        unpack(ctx)
    }

    nonisolated func session(_ session: WCSession,
                             didReceiveApplicationContext ctx: [String: Any]) {
        unpack(ctx)
    }

    // Live Guided Survey state pushed from the iPhone while surveying.
    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        guard message["type"] as? String == "guided" else { return }
        let active = message["active"] as? Bool ?? false
        let room = message["room"] as? String
        let recording = message["recording"] as? Bool ?? false
        let elapsed = message["elapsed"] as? Int ?? 0
        let completed = message["completed"] as? Int ?? 0
        let total = message["total"] as? Int ?? 0
        Task { @MainActor in
            self.applyGuided(active: active, room: room, recording: recording,
                             elapsed: elapsed, completed: completed, total: total)
        }
    }

    // Extract Sendable primitives from [String: Any] before crossing the actor boundary.
    private nonisolated func unpack(_ ctx: [String: Any]) {
        let g = ctx["grade"] as? String
        let s = ctx["score"] as? Int
        let d = ctx["deviceCount"] as? Int
        let o = ctx["offlineCount"] as? Int
        let b = ctx["brOffline"] as? Bool
        let t = ctx["ts"] as? TimeInterval
        Task { @MainActor in self.apply(grade: g, score: s, deviceCount: d, offlineCount: o, brOffline: b, ts: t) }
    }
}
