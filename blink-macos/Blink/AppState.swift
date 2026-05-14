import SwiftUI
import Combine
import os
import BlinkCore

private let log = Logger(subsystem: "com.blink20.app", category: "AppState")

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

    /// Score tick interval
    private static let scoreTickInterval: TimeInterval = 30

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

    // Persistence
    private let persistence = PersistenceManager()

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
        log.info("Blink starting up")
        setupCallbacks()
        loadTodayStats()

        // Defer permissions/monitoring until after onboarding
        if ThemeManager.shared.hasCompletedOnboarding {
            checkPermissionsAndStart()
        } else {
            log.info("Onboarding not complete — deferring permissions")
            NotificationCenter.default.addObserver(
                forName: .onboardingCompleted, object: nil, queue: .main
            ) { [weak self] _ in
                self?.onboardingCompleted()
            }
        }
    }

    /// Called after onboarding completes to start monitoring.
    func onboardingCompleted() {
        checkPermissionsAndStart()
    }

    private func setupCallbacks() {
        flowStateMachine.onStateChange = { [weak self] old, new in
            Task { @MainActor in
                guard let self else { return }
                let remainingBefore = self.timerStateMachine.remainingSeconds
                log.info("Flow state: \(old.rawValue) → \(new.rawValue)")
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
                    log.notice("⏱️ Timer extended: \(String(format: "%.0f", remainingBefore))s → \(String(format: "%.0f", remainingAfter))s (entered \(new.rawValue))")
                }

                if new == .breakPrompted {
                    self.isBreakPrompted = true
                }
            }
        }

        timerStateMachine.onBreakDue = { [weak self] in
            Task { @MainActor in
                log.notice("⏰ Timer reached zero — break due")
                self?.handleBreakDue()
            }
        }

        complianceTracker.onBreakRecorded = { [weak self] record in
            Task { @MainActor in
                log.info("Break recorded: compliance=\(record.compliance.rawValue), flowState=\(record.flowStateWhenPrompted.rawValue), score=\(String(format: "%.2f", record.flowScore))")
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
        hasAccessibilityPermission = PermissionManager.isPermissionGranted()
        log.info("Input permission: \(self.hasAccessibilityPermission)")

        if hasAccessibilityPermission {
            startMonitoring()
            startTimers()
            log.info("Monitors and timers started")
        } else {
            log.info("Waiting for permission — showing guide")

            // Show permission guide — user manually adds Blink in Accessibility settings
            permissionWindow = PermissionWindowController()
            permissionWindow?.show(theme: ThemeManager.shared.current)
            startPermissionPolling()
        }
    }

    private func startPermissionPolling() {
        func poll() {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                guard let self else { return }
                if PermissionManager.isPermissionGranted() {
                    log.info("Permission granted — starting up")
                    self.permissionWindow?.dismiss()
                    self.permissionWindow = nil
                    self.hasAccessibilityPermission = true
                    self.startMonitoring()
                    self.startTimers()
                } else {
                    poll()
                }
            }
        }
        poll()
    }

    private func startMonitoring() {
        log.info("Starting input monitoring (CGEventTap)")
        let input = MacInputMonitor()
        input.onKeystroke = { [weak self] event in
            self?.flowScoreCalculator.ingestKeystroke(event)
        }
        input.onMouseEvent = { [weak self] event in
            self?.flowScoreCalculator.ingestMouseEvent(event)
        }
        input.startMonitoring()
        self.inputMonitor = input

        log.info("Starting app monitor (NSWorkspace)")
        let appMon = MacAppMonitor()
        appMon.onAppSwitch = { [weak self] event in
            log.debug("App switch → \(event.appBundleID)")
            self?.flowScoreCalculator.recordAppSwitch(event)
            self?.breakpointDetector.recordAppSwitch(at: event.timestamp)
        }
        appMon.onWindowTitleChange = { [weak self] in
            log.debug("Window title changed")
            self?.flowScoreCalculator.recordWindowTitleChange(
                at: Date().timeIntervalSinceReferenceDate
            )
        }
        appMon.startMonitoring()
        self.appMonitor = appMon

        self.idleDetector = MacIdleDetector()
        self.contextDetector = MacContextDetector()
        log.info("All monitors active")
    }

    private func startTimers() {
        // 1-second tick for countdown
        tickTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tickCountdown()
            }
        }

        // Periodic tick for flow score
        scoreTimer = Timer.scheduledTimer(withTimeInterval: Self.scoreTickInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tickFlowScore()
            }
        }
    }

    private func tickCountdown() {
        // Check if a pending break can be delivered at a natural pause
        checkPendingBreak()

        guard !isBreakPrompted && !breakDuePending else { return }
        let before = timerStateMachine.remainingSeconds
        timerStateMachine.tick(flowState: flowState, deltaSeconds: 1.0)
        remainingSeconds = timerStateMachine.remainingSeconds

        // Timer extended due to flow state change — notify user
        if remainingSeconds > before + 1 {
            log.notice("⏱️ Timer extended: \(String(format: "%.0f", before))s → \(String(format: "%.0f", self.remainingSeconds))s (state=\(self.flowState.rawValue))")
            overlayController.showTimerExtendedToast { [weak self] in
                self?.showBreakPrompt()
            }
        }
    }

    private func tickFlowScore() {
        let now = Date().timeIntervalSinceReferenceDate
        let idle = idleDetector?.secondsSinceLastInput() ?? 0
        let intentionalIdle = idleDetector?.secondsSinceLastIntentionalInput() ?? 0
        let keystrokeIdle = idleDetector?.secondsSinceLastKeystroke() ?? 0
        let clickIdle = idleDetector?.secondsSinceLastClick() ?? 0
        let scrollIdle = idleDetector?.secondsSinceLastScroll() ?? 0
        let micActive = contextDetector?.isMicrophoneActive() ?? false

        // Feed breakpoint detector
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
            log.info("Video playback: \(videoPlaying ? "started" : "stopped")")
            if debugNotifications {
                overlayController.showDebugToast("Video \(videoPlaying ? "started" : "stopped")")
            }
        }
        isVideoPlaying = videoPlaying

        // Video playback = user is not doing close-up screen work → reset timer
        if videoPlaying {
            log.debug("Video playing — timer reset")
            if debugNotifications {
                overlayController.showDebugToast("Timer reset: video playing")
            }
            timerStateMachine.resetAfterBreak()
            remainingSeconds = timerStateMachine.remainingSeconds
            return
        }

        flowScore = flowScoreCalculator.currentScore(now: now)
        let inGracePeriod = lastBreakEndedAt.map { Date().timeIntervalSince($0) < Self.postBreakGraceSeconds } ?? false
        log.debug("Tick: score=\(String(format: "%.2f", self.flowScore)), idle=\(String(format: "%.0f", idle))s, state=\(self.flowState.rawValue), remaining=\(String(format: "%.0f", self.remainingSeconds))s\(inGracePeriod ? " [grace]" : "")")

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
            log.info("Idle \(String(format: "%.0f", idle))s ≥ \(String(format: "%.0f", Self.idleBreakThreshold))s — eyes rested, timer reset")
            if debugNotifications {
                overlayController.showDebugToast("Timer reset: idle \(Int(idle))s ≥ \(Int(Self.idleBreakThreshold))s")
            }
            consecutiveBreaksTaken = 0  // walked away — reset streak
            timerStateMachine.resetAfterBreak()
            remainingSeconds = timerStateMachine.remainingSeconds
        }
    }

    private func handleBreakDue() {
        let config = flowStateMachine.config
        let inFlow = flowState == .flow || flowState == .deepFlow

        if inFlow {
            switch config.breakDeliveryInFlow {
            case .waitForPause:
                // V1: wait for natural pause, then force overlay
                log.info("Break due in \(self.flowState.rawValue) — waiting for natural pause")
                breakDuePending = true
                breakDueSince = Date()
                return

            case .nudge:
                // V2: gentle nudge, never force during flow
                let minutes = Int(timerStateMachine.timerDuration) / 60
                log.info("Break due in \(self.flowState.rawValue) — showing nudge")
                overlayController.showFlowNudge(
                    message: "You've been focused for \(minutes) min",
                    onTakeBreak: { [weak self] in
                        Task { @MainActor in self?.showBreakPrompt() }
                    }
                )
                timerStateMachine.resetAfterBreak()
                remainingSeconds = timerStateMachine.remainingSeconds
                return

            case .nudgeWithEscalation:
                // V3: nudge first, escalate after N ignored nudges
                let maxNudges = config.maxNudgesBeforeForce

                if let max = maxNudges, nudgesIgnoredInCurrentFlow >= max {
                    // Escalate to forced break
                    log.info("Break due in \(self.flowState.rawValue) — \(self.nudgesIgnoredInCurrentFlow) nudges ignored, escalating to overlay")
                    nudgesIgnoredInCurrentFlow = 0
                    breakDuePending = true
                    breakDueSince = Date()
                    return
                }

                // Show nudge
                nudgesIgnoredInCurrentFlow += 1
                let minutes = Int(timerStateMachine.timerDuration) / 60
                let remaining = maxNudges.map { $0 - nudgesIgnoredInCurrentFlow + 1 }
                let suffix = remaining.map { " (\($0) left before forced)" } ?? ""
                log.info("Break due in \(self.flowState.rawValue) — nudge #\(self.nudgesIgnoredInCurrentFlow)\(suffix)")
                overlayController.showFlowNudge(
                    message: "You've been focused for \(minutes) min",
                    onTakeBreak: { [weak self] in
                        Task { @MainActor in
                            self?.nudgesIgnoredInCurrentFlow = 0
                            self?.showBreakPrompt()
                        }
                    }
                )
                timerStateMachine.resetAfterBreak()
                remainingSeconds = timerStateMachine.remainingSeconds
                return
            }
        }

        // Not in flow: wait for natural pause, then show overlay
        nudgesIgnoredInCurrentFlow = 0
        breakDuePending = true
        breakDueSince = Date()
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
        case .scoreBased, .activityGapAnyInput:
            // V1/V2: simple idle threshold
            isAtBreakpoint = idle >= Self.naturalPauseThreshold

        case .intentionalWithEscalation:
            // V3: compound breakpoint detection (keyboard→mouse, typing burst→silence, app switch)
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
            log.info("Breakpoint detected after \(String(format: "%.0f", waited))s wait — showing break")
            breakDuePending = false
            breakDueSince = nil
            showBreakPrompt()
            return
        }

        // Max wait exceeded — show nudge (not mid-keystroke, just between keystrokes)
        if waited >= Self.maxPauseWaitSeconds {
            log.info("Waited \(String(format: "%.0f", waited))s for breakpoint — delivering nudge")
            breakDuePending = false
            breakDueSince = nil
            timerStateMachine.resetAfterBreak()
            remainingSeconds = timerStateMachine.remainingSeconds
        }
    }

    func showBreakPrompt() {
        log.notice("🔔 Showing break overlay (score=\(String(format: "%.2f", self.flowScore)), state=\(self.flowState.rawValue))")
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
        log.info("✅ Break taken")
        consecutiveBreaksTaken += 1
        complianceTracker.breakTaken(at: Date(), idleDuration: 20)
        finishBreak()
    }

    func dismissBreak() {
        log.info("⏭️ Break skipped")
        complianceTracker.breakDismissed(at: Date())
        finishBreak()
    }

    func snoozeBreak(minutes: Int) {
        log.info("💤 Break snoozed for \(minutes) min")
        isBreakPrompted = false
        flowStateMachine.exitBreakPrompted()
        timerStateMachine.reset(duration: TimeInterval(minutes * 60))
        remainingSeconds = timerStateMachine.remainingSeconds
        overlayController.dismiss()
    }

    private func finishBreak() {
        lastBreakEndedAt = Date()
        log.info("Timer reset to \(String(format: "%.0f", self.timerStateMachine.normalDuration))s")
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
        log.info("Loaded today's stats: \(self.breaksTakenToday)/\(self.breaksPromptedToday) breaks taken")
    }
}
