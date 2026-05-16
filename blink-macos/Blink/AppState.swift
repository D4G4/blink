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

        // One-time migrations
        let onboardingVersion = UserDefaults.standard.integer(forKey: "onboardingVersion")
        if onboardingVersion < 2 {
            ThemeManager.shared.hasCompletedOnboarding = false
            UserDefaults.standard.set(2, forKey: "onboardingVersion")
            BlinkLog.app.info("Onboarding reset for new flow sensitivity UI")
        }
        // Build 27 bug auto-disabled mic detection — reset it
        if !UserDefaults.standard.bool(forKey: "micMigrationV1") {
            UserDefaults.standard.set(true, forKey: "pauseDuringCalls")
            UserDefaults.standard.set(true, forKey: "micMigrationV1")
            BlinkLog.app.info("Reset pauseDuringCalls to true (migration)")
        }

        setupCallbacks()
        loadTodayStats()

        // Defer permissions/monitoring until after onboarding
        if ThemeManager.shared.hasCompletedOnboarding {
            showTimerForStartup()
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
        showTimerForStartup()
        checkPermissionsAndStart()
    }

    private func setupCallbacks() {
        flowStateMachine.onStateChange = { [weak self] old, new in
            Task { @MainActor in
                guard let self else { return }
                let remainingBefore = self.timerStateMachine.remainingSeconds
                BlinkLog.app.info("Flow state: \(old.rawValue) → \(new.rawValue)")
                if self.debugNotifications {
                    self.overlayController.showDebugToast("State: \(old.rawValue) → \(new.rawValue)")
                }
                self.flowState = new

                // Reset nudge counter when exiting flow
                if (old == .flow || old == .deepFlow) && (new != .flow && new != .deepFlow) {
                    self.nudgesIgnoredInCurrentFlow = 0
                }

                let remainingAfter = self.timerStateMachine.remainingSeconds
                if remainingAfter > remainingBefore + 1 {
                    BlinkLog.app.info("⏱️ Timer extended: \(String(format: "%.0f", remainingBefore))s → \(String(format: "%.0f", remainingAfter))s (entered \(new.rawValue))")
                }

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
        if PermissionManager.isPermissionGranted() {
            hasAccessibilityPermission = true
            UserDefaults.standard.set(true, forKey: "permissionGranted")
            startMonitoring()
            startTimers()
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
                BlinkLog.app.info("Permission granted — monitors and timers started")

                // Show a toast pointing user to the menu bar
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.overlayController.showMenuBarWelcome()
                }
            }
        }
    }

    private func startMonitoring() {
        BlinkLog.app.info("Starting input monitoring (CGEventTap)")
        let input = MacInputMonitor()
        input.onKeystroke = { [weak self] event in
            self?.flowScoreCalculator.ingestKeystroke(event)
            self?.breakDecisionEngine.recordKeystroke()
        }
        input.onMouseEvent = { [weak self] event in
            self?.flowScoreCalculator.ingestMouseEvent(event)
            switch event.kind {
            case .click: self?.breakDecisionEngine.recordClick()
            case .scroll(_): self?.breakDecisionEngine.recordScroll()
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

        self.idleDetector = MacIdleDetector()
        let ctx = MacContextDetector()
        ctx.onMicActiveAtLaunch = { [weak self] in
            DispatchQueue.main.async {
                self?.micAlwaysOnWarning = true
            }
        }
        self.contextDetector = ctx
        BlinkLog.app.info("All monitors active")
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
        // Always tick as normal state — BreakDecisionEngine handles extensions at break time
        timerStateMachine.tick(flowState: .normal, deltaSeconds: 1.0)
        remainingSeconds = timerStateMachine.remainingSeconds
    }

    private func tickFlowScore() {
        let now = Date().timeIntervalSinceReferenceDate
        let idle = idleDetector?.secondsSinceLastInput() ?? 0
        let intentionalIdle = idleDetector?.secondsSinceLastIntentionalInput() ?? 0
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
        let decision = breakDecisionEngine.decide()

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

        let idle = idleDetector?.secondsSinceLastInput() ?? 0
        let waited = Date().timeIntervalSince(breakDueSince ?? Date())
        let strategy = flowStateMachine.strategy

        let isAtBreakpoint: Bool
        switch strategy {
        case .scoreBased:
            // V1: simple idle threshold
            isAtBreakpoint = idle >= Self.naturalPauseThreshold

        case .breakDecisionEngine:
            // V2: compound breakpoint detection (keyboard→mouse, typing burst→silence, app switch)
            let keystrokeIdle = idleDetector?.secondsSinceLastKeystroke() ?? 0
            let clickIdle = idleDetector?.secondsSinceLastClick() ?? 0
            let scrollIdle = idleDetector?.secondsSinceLastScroll() ?? 0
            let now = Date().timeIntervalSinceReferenceDate
            isAtBreakpoint = breakpointDetector.isAtBreakpoint(
                secondsSinceLastKeystroke: keystrokeIdle,
                secondsSinceLastClick: clickIdle,
                secondsSinceLastScroll: scrollIdle,
                now: now
            )
        }

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
