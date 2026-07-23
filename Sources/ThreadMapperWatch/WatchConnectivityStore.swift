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

    override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
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
