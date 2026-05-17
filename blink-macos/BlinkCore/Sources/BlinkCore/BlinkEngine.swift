import Foundation

/// Central orchestrator for Blink's break reminder logic.
///
/// Receives input events and a 1-second tick from the platform layer.
/// Produces callbacks when the UI needs to show a break, toast, or update.
///
/// All decision logic lives here — the platform layer is just plumbing.
public final class BlinkEngine {

    // MARK: - Callbacks (set by the platform layer)

    /// Show the fullscreen break overlay. `breakNumber` is for walk suggestion (≥4).
    public var onShowBreak: ((_ breakNumber: Int) -> Void)?

    /// Show a toast when the timer extends (e.g., "Active typing — +10 min").
    public var onShowExtendToast: ((_ reason: String) -> Void)?

    /// Timer countdown updated — drives the menu bar display.
    public var onTimerUpdate: ((_ remaining: TimeInterval, _ total: TimeInterval) -> Void)?

    /// State changed — drives the menu bar badge (Working/Away/Meeting/Break).
    public var onStateChange: ((_ state: DisplayState) -> Void)?

    /// Log a message (debug toast, console, etc.)
    public var onLog: ((_ message: String) -> Void)?

    public enum DisplayState: String {
        case working, away, meeting, onBreak
    }

    // MARK: - Configuration

    /// User's sensitivity setting (0.4–0.9). Drives maxExtensions and score threshold.
    public var sensitivity: Double = 0.7 {
        didSet {
            config = FlowConfig.config(forSensitivity: sensitivity)
            decisionEngine.sensitivity = sensitivity
        }
    }

    /// Wall-clock cap: force a break after this many seconds since the last break,
    /// regardless of idle pauses or extensions. User-configurable. Default 40 min.
    public var maxWallClockSeconds: TimeInterval = 2400

    // MARK: - Sub-engines

    private let timer = TimerStateMachine()
    private let stateMachine = FlowStateMachine()
    private let decisionEngine = BreakDecisionEngine()
    private let complianceTracker = BreakComplianceTracker()
    private var config: FlowConfig

    // MARK: - Activity timestamps (single source of truth for idle)

    private var lastKeystrokeTime = Date()
    private var lastClickTime = Date()
    private var lastScrollTime = Date()
    private var lastAppSwitchTime = Date()

    private var lastActivityTime: Date {
        max(lastKeystrokeTime, lastClickTime, lastScrollTime, lastAppSwitchTime)
    }

    private var idle: TimeInterval {
        Date().timeIntervalSince(lastActivityTime)
    }

    private var keyboardIdle: TimeInterval {
        Date().timeIntervalSince(lastKeystrokeTime)
    }

    // MARK: - State

    private var breakPending = false
    private var breakPendingSince: Date?
    private var consecutiveBreaks: Int = 0
    private var lastBreakEndedAt: Date?
    private var engineStartTime = Date()
    private var isOnBreak = false
    private var micActive = false
    private var cameraActive = false
    private var videoPlaying = false

    // MARK: - Constants

    private let graceSeconds: TimeInterval = 60
    private let idleThreshold: TimeInterval = 180
    private let courtesyWaitMax: TimeInterval = 10
    private let courtesyGap: TimeInterval = 3

    // MARK: - Init

    public init() {
        self.config = FlowConfig.config(forSensitivity: sensitivity)

        timer.onBreakDue = { [weak self] in
            self?.handleBreakDue()
        }
    }

    // MARK: - Input (called by platform layer)

    public func recordKeystroke() {
        lastKeystrokeTime = Date()
        decisionEngine.recordKeystroke()
    }

    public func recordClick() {
        lastClickTime = Date()
        decisionEngine.recordClick()
    }

    public func recordScroll() {
        lastScrollTime = Date()
        decisionEngine.recordScroll()
    }

    public func recordAppSwitch(bundleID: String) {
        lastAppSwitchTime = Date()
        decisionEngine.recordAppSwitch(bundleID: bundleID)
    }

    public func setMicActive(_ active: Bool) {
        micActive = active
    }

    public func setCameraActive(_ active: Bool) {
        cameraActive = active
    }

    public func setVideoPlaying(_ playing: Bool) {
        if playing != videoPlaying {
            videoPlaying = playing
            if playing {
                // Video playback = not close-up screen work → reset timer
                timer.resetAfterBreak()
                decisionEngine.resetAll()
                onTimerUpdate?(timer.remainingSeconds, timer.timerDuration)
            }
        }
    }

    public func wakeFromSleep() {
        // Idle is automatically correct from timestamps.
        // Force an immediate check so we don't wait for the next tick.
        tickInternal()
    }

    // MARK: - Break response (called by platform layer)

    public func userTookBreak() {
        consecutiveBreaks += 1
        complianceTracker.breakTaken(at: Date(), idleDuration: 20)
        finishBreak()
    }

    public func userSkippedBreak() {
        complianceTracker.breakDismissed(at: Date())
        finishBreak()
    }

    public func userSnoozed(minutes: Int) {
        isOnBreak = false
        timer.reset(duration: TimeInterval(minutes * 60))
        onTimerUpdate?(timer.remainingSeconds, timer.timerDuration)
        onStateChange?(.working)
    }

    // MARK: - Tick (called every 1 second by platform layer)

    public func tick() {
        tickInternal()
    }

    private func tickInternal() {
        // 1. Pending break delivery (10s courtesy wait for keyboard gap)
        if breakPending {
            let waited = Date().timeIntervalSince(breakPendingSince ?? Date())
            if waited >= courtesyWaitMax || keyboardIdle >= courtesyGap {
                breakPending = false
                breakPendingSince = nil
                isOnBreak = true
                complianceTracker.breakPrompted(at: Date(), flowState: .normal, flowScore: 0)
                onShowBreak?(consecutiveBreaks + 1)
                onStateChange?(.onBreak)
            }
            return
        }

        // Don't tick while break overlay is showing
        if isOnBreak { return }

        // 2. Wall-clock safety cap
        let sinceLastBreak = Date().timeIntervalSince(lastBreakEndedAt ?? engineStartTime)
        if sinceLastBreak >= maxWallClockSeconds {
            breakPending = true
            breakPendingSince = Date()
            return
        }

        // 3. Grace period (suppress idle detection for 60s after break)
        let inGrace = lastBreakEndedAt.map { Date().timeIntervalSince($0) < graceSeconds } ?? false

        // 4. Idle/meeting detection
        let currentIdle = inGrace ? 0 : idle
        stateMachine.tick(
            flowScore: 0,
            secondsSinceLastInput: currentIdle,
            isMicActive: micActive,
            isCameraActive: cameraActive,
            now: Date().timeIntervalSinceReferenceDate
        )

        let newState = displayState(from: stateMachine.state)
        onStateChange?(newState)

        // 5. Idle reset (eyes already rested)
        if currentIdle >= idleThreshold && !inGrace {
            consecutiveBreaks = 0
            decisionEngine.resetAll()
            timer.resetAfterBreak()
            onTimerUpdate?(timer.remainingSeconds, timer.timerDuration)
            return
        }

        // 6. Video playing — already handled in setVideoPlaying, but skip timer tick
        if videoPlaying { return }

        // 7. Tick timer (pauses if idle/meeting)
        let timerState: FlowState = (stateMachine.state == .idle || stateMachine.state == .meeting)
            ? stateMachine.state : .normal
        timer.tick(flowState: timerState, deltaSeconds: 1.0)
        onTimerUpdate?(timer.remainingSeconds, timer.timerDuration)
    }

    // MARK: - Break decision

    private func handleBreakDue() {
        let decision = decisionEngine.decide(maxExtensions: config.maxExtensions)

        switch decision {
        case .extend(_, let reason):
            decisionEngine.resetWindow()
            timer.reset(duration: 10 * 60)
            onShowExtendToast?(reason)
            onTimerUpdate?(timer.remainingSeconds, timer.timerDuration)

        case .showBreak:
            decisionEngine.resetWindow()
            breakPending = true
            breakPendingSince = Date()
        }
    }

    private func finishBreak() {
        lastBreakEndedAt = Date()
        isOnBreak = false
        decisionEngine.resetWindow()
        timer.resetAfterBreak()
        onTimerUpdate?(timer.remainingSeconds, timer.timerDuration)
        onStateChange?(.working)
    }

    private func displayState(from state: FlowState) -> DisplayState {
        switch state {
        case .idle: return .away
        case .meeting: return .meeting
        case .breakPrompted: return .onBreak
        default: return .working
        }
    }

    // MARK: - Public state accessors

    public var remainingSeconds: TimeInterval { timer.remainingSeconds }
    public var timerDuration: TimeInterval { timer.timerDuration }
    public var currentBreakStreak: Int { consecutiveBreaks }
    public var currentState: DisplayState { displayState(from: stateMachine.state) }

    /// Compliance tracker — expose for persistence in the app layer.
    public var compliance: BreakComplianceTracker { complianceTracker }
}
