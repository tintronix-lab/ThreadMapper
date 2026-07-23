import Observation

/// Coordinates the phone's Guided Survey flow with the Apple Watch remote.
///
/// `GuidedSurveyView` owns the flow (room list, current room, recording, the
/// sampling loop) and, while on screen, registers Start/Done/Skip handlers here
/// and publishes its state. The watch's button taps arrive via
/// `WatchConnectivityManager` and are dispatched to those handlers; every state
/// change is pushed back to the watch so its controls stay in sync.
///
/// This is a *remote control* for a survey the phone is actively running — the
/// phone must stay awake so its sampling loop keeps going (the app is not
/// configured for background location).
@MainActor
@Observable
final class GuidedSurveyBridge {
    static let shared = GuidedSurveyBridge()

    private(set) var isActive = false
    private(set) var currentRoom: String?
    private(set) var isRecording = false
    private(set) var elapsedSeconds = 0
    private(set) var completed = 0
    private(set) var total = 0

    /// Registered by `GuidedSurveyView` while it is on screen; cleared on exit.
    @ObservationIgnored var onStart: (() -> Void)?
    @ObservationIgnored var onDoneRoom: (() -> Void)?
    @ObservationIgnored var onSkip: (() -> Void)?

    private init() {}

    /// Called by `GuidedSurveyView` whenever its state changes; mirrors it to the watch.
    func publish(active: Bool, room: String?, recording: Bool,
                 elapsed: Int, completed: Int, total: Int) {
        isActive = active
        currentRoom = room
        isRecording = recording
        elapsedSeconds = elapsed
        self.completed = completed
        self.total = total
        WatchConnectivityManager.shared.sendGuidedState(
            active: active, room: room, recording: recording,
            elapsed: elapsed, completed: completed, total: total
        )
    }

    /// The guided survey left the screen — tell the watch there's nothing to control.
    func deactivate() {
        onStart = nil
        onDoneRoom = nil
        onSkip = nil
        publish(active: false, room: nil, recording: false, elapsed: 0, completed: 0, total: 0)
    }

    /// Dispatches a command received from the watch to the registered handler.
    func handleCommand(_ command: String) {
        switch command {
        case "start": onStart?()
        case "done":  onDoneRoom?()
        case "skip":  onSkip?()
        default:      break
        }
    }
}
