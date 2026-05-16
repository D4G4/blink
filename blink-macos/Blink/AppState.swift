import SwiftUI
import Combine
import BlinkCore

/// Central app state that coordinates all subsystems.
@MainActor
final class AppState: ObservableObject {
    // Published state for UI
    @Published var remainingSeconds: TimeInterval = 1200
    @Published var flowState: FlowState = .normal
    @Published var flowScore: Double = 0.0
    @Published var isBreakPrompted: Bool = false
    @Published var breaksTakenToday: Int = 0
    @Published var breaksPromptedToday: Int = 0
    @Published var hasAccessibilityPermission: Bool = false
    @Published var isVideoPlaying: Bool = false
    @Published var micAlwaysOnWarning: Bool = false
    @AppStorage("debugNotifications") var debugNotifications: Bool = false

    // Core engine
    let flowScoreCalculator = FlowScoreCalculator()
    let flowStateMachine = FlowStateMachine()
    let timerStateMachine = TimerStateMachine()
    let complianceTracker = BreakComplianceTracker()
    let adaptiveEngine = AdaptiveTimingEngine()

    // Platform monitors
    private var inputMonitor: MacInputMonitor?
    private var appMonitor: MacAppMonitor?
    private var idleDetector: MacIdleDetector?
    private var contextDetector: MacContextDetector?
    private var permissionWindow: PermissionWindowController?

    // Timers
    private var tickTimer: Timer?
    private var scoreTimer: Timer?

    // MARK: - Constants

    /// How long the user must be idle (zero input) before it counts as a break
    /// 90s = long enough that "reading agent output" with occasional scrolls won't trigger it,
    /// but short enough to catch actually walking away
    private static let idleBreakThreshold: TimeInterval = 180

    /// Input gap that counts as a "natural pause" for delivering a pending break
    private static let naturalPauseThreshold: TimeInterval = 6

    /// Max time to wait for a natural pause before giving up
    private static let maxPauseWaitSeconds: TimeInterval = 300

    /// Grace period after a break — ignore idle detection so user can settle back in
    private static let postBreakGraceSeconds: TimeInterval = 60

    /// Score tick interval — 5s in debug mode for faster mic detection testing, 30s normal
    private var scoreTickInterval: TimeInterval {
        debugNotifications ? 5 : 30
    }

    // Natural pause detection for flow states
    private var breakDuePending: Bool = false
    private var breakDueSince: Date?
    private var lastBreakEndedAt: Date?

    // Consecutive break tracking — resets after 30 min idle or walk-away
    private var consecutiveBreaksTaken: Int = 0

    // Nudge escalation tracking (V3) — counts ignored nudges in current flow session
    private var nudgesIgnoredInCurrentFlow: Int = 0

    /// Wall-clock time of last real user input (keystroke, click, scroll — NOT mouse move,
    /// NOT system wake events). Used to detect idle across Mac sleep cycles, since
    /// CGEventSource counters reset on wake.
    private var lastRealInputTime: Date = Date()
    private var sleepWakeObserver: NSObjectProtocol?

    // Break overlay
    private let overlayController = OverlayWindowController()
    private let breakpointDetector = BreakpointDetector()
    public let breakDecisionEngine = BreakDecisionEngine()

    // Persistence
    private let persistence = PersistenceManager()
    private var onboardingObserver: NSObjectProtocol?

    var formattedRemaining: String {
        let mins = Int(remainingSeconds) / 60
        let secs = Int(remainingSeconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }

    var menuBarIconName: String {
        if isBreakPrompted { return "eye.trianglebadge.exclamationmark" }
        if isVideoPlaying { return "play.circle" }
        switch flowState {
        case .flow, .deepFlow: return "eye.circle.fill"
        case .idle: return "eye.slash"
        case .meeting: return "eye.slash"
        default: return "eye"
        }
    }

    init(preview: Bool = false) {
        if preview {
            hasAccessibilityPermission = true
            return
        }
        BlinkLog.app.info("Blink starting up")

        // One-time: force re-onboarding for build 20 (new flow sensitivity UI)
        let onboardingVersion = UserDefaults.standard.integer(forKey: "onboardingVersion")
        if onboardingVersion < 2 {
            ThemeManager.shared.hasCompletedOnboarding = false
            UserDefaults.standard.set(2, forKey: "onboardingVersion")
            BlinkLog.app.info("Onboarding reset for new flow sensitivity UI")
        }

        setupCallbacks()
        loadTodayStats()

        // Defer permissions/monitoring until after onboarding
        if ThemeManager.shared.hasCompletedOnboarding {
            checkPermissionsAndStart()
        } else {
            BlinkLog.app.info("Onboarding not complete — deferring permissions")
            onboardingObserver = NotificationCenter.default.addObserver(
                forName: .onboardingCompleted, object: nil, queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.onboardingCompleted()
                }
            }
        }
    }

    /// Open the menu bar popup on startup so user sees Blink is running.
    private func showTimerForStartup() {
        findStatusItemAndOpen(attempts: 0)
    }

    private func findStatusItemAndOpen(attempts: Int) {
        guard attempts < 10 else {
            BlinkLog.app.info("MenuBarController: gave up finding status item after 10 attempts")
            return
        }
        let delay = 0.3 * Double(attempts + 1)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            MenuBarController.shared.findStatusItem()
            if MenuBarController.shared.statusItem != nil {
                BlinkLog.app.info("MenuBarController: found status item on attempt \(attempts + 1)")
                MenuBarController.shared.open()
            } else {
                self.findStatusItemAndOpen(attempts: attempts + 1)
            }
        }
    }

    /// Called after onboarding completes to start monitoring.
    func onboardingCompleted() {
        if let observer = onboardingObserver {
            NotificationCenter.default.removeObserver(observer)
            onboardingObserver = nil
        }
        // Don't open menu bar yet — wait until permission is confirmed.
        // showTimerForStartup() is called inside checkPermissionsAndStart()
        // only after the user grants accessibility permission.
        checkPermissionsAndStart()
    }

    private func setupCallbacks() {
        flowStateMachine.onStateChange = { [weak self] old, new in
            Task { @MainActor in
                guard let self else { return }
                BlinkLog.app.info("State: \(old.rawValue) → \(new.rawValue)")
                if self.debugNotifications {
                    self.overlayController.showDebugToast("State: \(old.rawValue) → \(new.rawValue)")
                }
                self.flowState = new

                if new == .breakPrompted {
                    self.isBreakPrompted = true
                }
            }
        }

        timerStateMachine.onBreakDue = { [weak self] in
            Task { @MainActor in
                BlinkLog.app.info("⏰ Timer reached zero — break due")
                self?.handleBreakDue()
            }
        }

        complianceTracker.onBreakRecorded = { [weak self] record in
            Task { @MainActor in
                BlinkLog.app.info("Break recorded: compliance=\(record.compliance.rawValue), flowState=\(record.flowStateWhenPrompted.rawValue), score=\(String(format: "%.2f", record.flowScore))")
                self?.persistence.saveBreakRecord(record)
                if record.compliance == .taken || record.compliance == .delayed {
                    self?.breaksTakenToday += 1
                    if let interval = record.breakDurationSeconds {
                        self?.adaptiveEngine.recordAcceptedBreak(intervalSinceLastBreak: interval)
                    }
                }
            }
        }
    }

    private func checkPermissionsAndStart() {
        // Always try the probe — handles updates where flag wasn't set
        let granted = PermissionManager.isPermissionGranted()
        BlinkLog.app.info("Permission probe result: \(granted)")
        if granted {
            hasAccessibilityPermission = true
            UserDefaults.standard.set(true, forKey: "permissionGranted")
            startMonitoring()
            startTimers()
            showTimerForStartup()
            BlinkLog.app.info("Permission confirmed — monitors and timers started")
        } else {
            BlinkLog.app.info("Permission not granted — showing guide")
            hasAccessibilityPermission = false
            permissionWindow = PermissionWindowController()
            permissionWindow?.show(theme: ThemeManager.shared.current) { [weak self] in
                guard let self else { return }
                UserDefaults.standard.set(true, forKey: "permissionGranted")
                self.permissionWindow = nil
                self.hasAccessibilityPermission = true
                self.startMonitoring()
                self.startTimers()
                self.showTimerForStartup()
                BlinkLog.app.info("Permission granted — monitors and timers started")
            }
        }
    }

    private func startMonitoring() {
        BlinkLog.app.info("Starting input monitoring (CGEventTap)")
        let input = MacInputMonitor()
        input.onKeystroke = { [weak self] event in
            self?.lastRealInputTime = Date()
            self?.flowScoreCalculator.ingestKeystroke(event)
            self?.breakDecisionEngine.recordKeystroke()
        }
        input.onMouseEvent = { [weak self] event in
            self?.flowScoreCalculator.ingestMouseEvent(event)
            switch event.kind {
            case .click:
                self?.lastRealInputTime = Date()
                self?.breakDecisionEngine.recordClick()
            case .scroll(_):
                self?.lastRealInputTime = Date()
                self?.breakDecisionEngine.recordScroll()
            case .move(_, _): break // ambient, don't count
            }
        }
        input.startMonitoring()
        self.inputMonitor = input

        BlinkLog.app.info("Starting app monitor (NSWorkspace)")
        let appMon = MacAppMonitor()
        appMon.onAppSwitch = { [weak self] event in
            BlinkLog.app.debug("App switch → \(event.appBundleID)")
            self?.flowScoreCalculator.recordAppSwitch(event)
            self?.breakpointDetector.recordAppSwitch(at: event.timestamp)
            self?.breakDecisionEngine.recordAppSwitch(bundleID: event.appBundleID)
        }
        appMon.onWindowTitleChange = { [weak self] in
            BlinkLog.app.debug("Window title changed")
            self?.flowScoreCalculator.recordWindowTitleChange(
                at: Date().timeIntervalSinceReferenceDate
            )
        }
        appMon.startMonitoring()
        self.appMonitor = appMon

        // Detect Mac wake from sleep — CGEventSource idle counters reset on wake,
        // so we check wall-clock time since last real input instead.
        sleepWakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleWakeFromSleep()
        }

        self.idleDetector = MacIdleDetector()
        let ctx = MacContextDetector()
        ctx.onMicActiveAtLaunch = { [weak self] in
            DispatchQueue.main.async {
                self?.micAlwaysOnWarning = true
            }
        }
        self.contextDetector = ctx
        BlinkLog.app.info("All monitors active")

        // Check mic immediately so Dictation/Siri warning shows at launch
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            _ = self?.contextDetector?.isMicrophoneActive()
        }
    }

    private func startTimers() {
        // 1-second tick for countdown
        tickTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tickCountdown()
            }
        }

        // Periodic tick for flow score
        scoreTimer = Timer.scheduledTimer(withTimeInterval: scoreTickInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tickFlowScore()
            }
        }
    }

    private func tickCountdown() {
        // Check if a pending break can be delivered at a natural pause
        checkPendingBreak()

        guard !isBreakPrompted && !breakDuePending else { return }
        // Pass real state for pause (idle/meeting) but clamp flow/deepFlow to normal
        // so TimerStateMachine doesn't do V1 proportional extension — BreakDecisionEngine handles that
        let timerState: FlowState = (flowState == .idle || flowState == .meeting) ? flowState : .normal
        timerStateMachine.tick(flowState: timerState, deltaSeconds: 1.0)
        remainingSeconds = timerStateMachine.remainingSeconds
    }

    /// Called on NSWorkspace.didWakeNotification. CGEventSource idle counters reset
    /// on wake (trackpad touch to see lock screen counts as input), so we check
    /// wall-clock time since the last real keystroke/click/scroll instead.
    private func handleWakeFromSleep() {
        let realIdle = Date().timeIntervalSince(lastRealInputTime)
        BlinkLog.app.info("Wake from sleep — \(String(format: "%.0f", realIdle))s since last real input")
        if realIdle >= Self.idleBreakThreshold {
            // User was away long enough — force idle state so timer pauses
            BlinkLog.app.info("Real idle \(String(format: "%.0f", realIdle))s >= \(Int(Self.idleBreakThreshold))s — entering idle")
            flowStateMachine.tick(
                flowScore: 0,
                secondsSinceLastInput: realIdle,
                secondsSinceLastIntentionalInput: realIdle,
                isMicActive: false,
                isCameraActive: false,
                now: Date().timeIntervalSinceReferenceDate
            )
            flowState = flowStateMachine.state
        }
    }

    private func tickFlowScore() {
        let now = Date().timeIntervalSinceReferenceDate
        // Use the larger of CGEventSource idle and wall-clock idle, so sleep
        // cycles that reset CGEventSource counters don't mask true idle time.
        let cgIdle = idleDetector?.secondsSinceLastInput() ?? 0
        let realIdle = Date().timeIntervalSince(lastRealInputTime)
        let idle = max(cgIdle, realIdle)
        let cgIntentionalIdle = idleDetector?.secondsSinceLastIntentionalInput() ?? 0
        let intentionalIdle = max(cgIntentionalIdle, realIdle)
        let keystrokeIdle = idleDetector?.secondsSinceLastKeystroke() ?? 0
        let clickIdle = idleDetector?.secondsSinceLastClick() ?? 0
        let scrollIdle = idleDetector?.secondsSinceLastScroll() ?? 0
        let micActive = contextDetector?.isMicrophoneActive() ?? false

        // Feed engines
        breakDecisionEngine.tick(now: now)
        breakpointDetector.recordInput(
            secondsSinceLastKeystroke: keystrokeIdle,
            secondsSinceLastClick: clickIdle,
            secondsSinceLastScroll: scrollIdle,
            now: now
        )
        let camActive = contextDetector?.isCameraActive() ?? false

        // Check if user is actively watching video
        let videoPlaying = contextDetector?.isMediaPlaying() ?? false

        if videoPlaying != isVideoPlaying {
            BlinkLog.app.info("Video playback: \(videoPlaying ? "started" : "stopped")")
            if debugNotifications {
                overlayController.showDebugToast("Video \(videoPlaying ? "started" : "stopped")")
            }
        }
        isVideoPlaying = videoPlaying

        // Video playback = user is not doing close-up screen work → reset timer
        if videoPlaying {
            BlinkLog.app.debug("Video playing — timer reset")
            if debugNotifications {
                overlayController.showDebugToast("Timer reset: video playing")
            }
            timerStateMachine.resetAfterBreak()
            remainingSeconds = timerStateMachine.remainingSeconds
            return
        }

        flowScore = flowScoreCalculator.currentScore(now: now)
        let inGracePeriod = lastBreakEndedAt.map { Date().timeIntervalSince($0) < Self.postBreakGraceSeconds } ?? false
        BlinkLog.app.debug("Tick: score=\(String(format: "%.2f", self.flowScore)), idle=\(String(format: "%.0f", idle))s, state=\(self.flowState.rawValue), remaining=\(String(format: "%.0f", self.remainingSeconds))s\(inGracePeriod ? " [grace]" : "")")

        flowStateMachine.tick(
            flowScore: flowScore,
            secondsSinceLastInput: inGracePeriod ? 0 : idle,
            secondsSinceLastIntentionalInput: inGracePeriod ? 0 : intentionalIdle,
            isMicActive: micActive,
            isCameraActive: camActive,
            now: now
        )

        // Idle ≥ threshold = eyes already rested, reset timer
        if hasAccessibilityPermission && idle >= Self.idleBreakThreshold && !isBreakPrompted && !inGracePeriod {
            BlinkLog.app.info("Idle \(String(format: "%.0f", idle))s ≥ \(String(format: "%.0f", Self.idleBreakThreshold))s — eyes rested, timer reset")
            if debugNotifications {
                overlayController.showDebugToast("Timer reset: idle \(Int(idle))s ≥ \(Int(Self.idleBreakThreshold))s")
            }
            consecutiveBreaksTaken = 0  // walked away — reset streak
            breakDecisionEngine.resetAll()  // reset signal window + extension count
            timerStateMachine.resetAfterBreak()
            remainingSeconds = timerStateMachine.remainingSeconds
        }
    }

    private func handleBreakDue() {
        // Timer fired — evaluate 20 min of collected signals
        let decision = breakDecisionEngine.decide(maxExtensions: flowStateMachine.config.maxExtensions)

        switch decision {
        case .extend(let minutes, let reason):
            // User is doing focused work — extend by 10 min, show gentle nudge
            BlinkLog.app.info("Break decision: extend to \(minutes) min — \(reason)")
            overlayController.showFlowNudge(
                message: "\(reason) — +10 min",
                onTakeBreak: { [weak self] in
                    Task { @MainActor in self?.showBreakPrompt() }
                }
            )
            // Add 10 minutes, not reset to 10
            timerStateMachine.reset(duration: 10 * 60)
            remainingSeconds = timerStateMachine.remainingSeconds
            // Don't reset window — accumulate signals for richer next evaluation

        case .showBreak:
            // User has been actively using screen — wait for natural pause, show overlay
            BlinkLog.app.info("Break decision: show break")
            breakDecisionEngine.resetWindow()
            breakDuePending = true
            breakDueSince = Date()

        case .nudge:
            // Low activity but still screen time — gentle reminder
            BlinkLog.app.info("Break decision: nudge — low activity but eyes still need rest")
            overlayController.showFlowNudge(
                message: "You've been at your screen for 20 min — rest your eyes",
                onTakeBreak: { [weak self] in
                    Task { @MainActor in self?.showBreakPrompt() }
                }
            )
            breakDecisionEngine.resetWindow()
            timerStateMachine.resetAfterBreak()
            remainingSeconds = timerStateMachine.remainingSeconds

        case .skip:
            // Barely any activity — silently reset
            BlinkLog.app.info("Break decision: skip — barely any activity")
            breakDecisionEngine.resetWindow()
            timerStateMachine.resetAfterBreak()
            remainingSeconds = timerStateMachine.remainingSeconds
        }
    }

    /// Check if a pending break can now be delivered at a natural boundary.
    /// Called every second from tickCountdown.
    /// V1/V2: simple 6s idle pause. V3: compound breakpoint detection.
    private func checkPendingBreak() {
        guard breakDuePending else { return }

        let waited = Date().timeIntervalSince(breakDueSince ?? Date())

        // Compound breakpoint detection (keyboard→mouse, typing burst→silence, app switch)
        let keystrokeIdle = idleDetector?.secondsSinceLastKeystroke() ?? 0
        let clickIdle = idleDetector?.secondsSinceLastClick() ?? 0
        let scrollIdle = idleDetector?.secondsSinceLastScroll() ?? 0
        let now = Date().timeIntervalSinceReferenceDate
        let isAtBreakpoint = breakpointDetector.isAtBreakpoint(
            secondsSinceLastKeystroke: keystrokeIdle,
            secondsSinceLastClick: clickIdle,
            secondsSinceLastScroll: scrollIdle,
            now: now
        )

        if isAtBreakpoint {
            BlinkLog.app.info("Breakpoint detected after \(String(format: "%.0f", waited))s wait — showing break")
            breakDuePending = false
            breakDueSince = nil
            showBreakPrompt()
            return
        }

        // Max wait exceeded — show nudge (not mid-keystroke, just between keystrokes)
        if waited >= Self.maxPauseWaitSeconds {
            BlinkLog.app.info("Waited \(String(format: "%.0f", waited))s for breakpoint — delivering nudge")
            breakDuePending = false
            breakDueSince = nil
            timerStateMachine.resetAfterBreak()
            remainingSeconds = timerStateMachine.remainingSeconds
        }
    }

    func showBreakPrompt() {
        BlinkLog.app.info("🔔 Showing break overlay (score=\(String(format: "%.2f", self.flowScore)), state=\(self.flowState.rawValue))")
        flowStateMachine.enterBreakPrompted()
        isBreakPrompted = true
        breaksPromptedToday += 1

        complianceTracker.breakPrompted(
            at: Date(),
            flowState: flowState,
            flowScore: flowScore
        )

        // 3s countdown → 20s screen takeover
        overlayController.showBreak(
            breakNumber: consecutiveBreaksTaken + 1,
            onComplete: { [weak self] in
                Task { @MainActor in self?.takeBreak() }
            },
            onSkip: { [weak self] in
                Task { @MainActor in self?.dismissBreak() }
            }
        )
    }

    func takeBreak() {
        BlinkLog.app.info("✅ Break taken")
        consecutiveBreaksTaken += 1
        complianceTracker.breakTaken(at: Date(), idleDuration: 20)
        finishBreak()
    }

    func dismissBreak() {
        BlinkLog.app.info("⏭️ Break skipped")
        complianceTracker.breakDismissed(at: Date())
        finishBreak()
    }

    func snoozeBreak(minutes: Int) {
        BlinkLog.app.info("💤 Break snoozed for \(minutes) min")
        isBreakPrompted = false
        flowStateMachine.exitBreakPrompted()
        timerStateMachine.reset(duration: TimeInterval(minutes * 60))
        remainingSeconds = timerStateMachine.remainingSeconds
        overlayController.dismiss()
    }

    private func finishBreak() {
        lastBreakEndedAt = Date()
        BlinkLog.app.info("Timer reset to \(String(format: "%.0f", self.timerStateMachine.normalDuration))s")
        isBreakPrompted = false
        flowStateMachine.exitBreakPrompted()
        timerStateMachine.resetAfterBreak()
        remainingSeconds = timerStateMachine.remainingSeconds
        overlayController.dismiss()
    }

    private func loadTodayStats() {
        let records = persistence.loadTodayRecords()
        breaksPromptedToday = records.count
        breaksTakenToday = records.filter { $0.compliance == .taken || $0.compliance == .delayed }.count
        BlinkLog.app.info("Loaded today's stats: \(self.breaksTakenToday)/\(self.breaksPromptedToday) breaks taken")
    }
}
