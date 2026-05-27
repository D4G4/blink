import SwiftUI
import Combine
import BlinkCore

/// Thin adapter between platform (macOS) and BlinkEngine (core logic).
/// Wires CGEventTap/NSWorkspace events into the engine and responds to callbacks with UI.
@MainActor
final class AppState: ObservableObject {
    // Published state for UI
    @Published var remainingSeconds: TimeInterval = 1200
    @Published var timerTotal: TimeInterval = 1200
    @Published var displayState: BlinkEngine.DisplayState = .working
    @Published var isBreakPrompted: Bool = false
    @Published var breaksTakenToday: Int = 0
    @Published var breaksPromptedToday: Int = 0
    @Published var hasInputMonitoringPermission: Bool = false
    @Published var isVideoPlaying: Bool = false
    @Published var isPaused: Bool = false
    @Published var micAlwaysOnWarning: Bool = false
    @AppStorage("debugNotifications") var debugNotifications: Bool = false

    // Engine
    public let engine = BlinkEngine()

    // Platform monitors
    private var inputMonitor: MacInputMonitor?
    private var appMonitor: MacAppMonitor?
    private var contextDetector: MacContextDetector?
    private var permissionWindow: PermissionWindowController?
    private var micPermissionWindow: MicrophonePermissionWindowController?

    // Timers
    private var tickTimer: Timer?

    // Sleep / lock tracking — used to suppress overlay when user is away
    private var isSystemAsleep = false

    // Kill-switch: hard timeout if overlay is stuck beyond any reasonable duration
    private var overlayShownAt: Date?
    private static let overlayMaxSeconds: TimeInterval = 120

    // Day tracking — reset break counters at midnight
    private var lastStatsDay: Int = Calendar.current.component(.day, from: Date())

    // Break overlay
    private let overlayController = OverlayWindowController()

    // Persistence
    private let persistence = PersistenceManager()
    private var onboardingObserver: NSObjectProtocol?

    // MARK: - Computed

    var formattedRemaining: String {
        let mins = Int(remainingSeconds) / 60
        let secs = Int(remainingSeconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }

    var flowState: FlowState {
        switch displayState {
        case .working: return .normal
        case .away: return .idle
        case .meeting: return .meeting
        case .onBreak: return .breakPrompted
        }
    }

    /// True when the screen is at the login window / screensaver lock.
    private var isScreenLocked: Bool {
        guard let dict = CGSessionCopyCurrentDictionary() as? [String: Any] else { return false }
        return dict["CGSSessionScreenIsLocked"] as? Bool ?? false
    }

    /// True when the user can't possibly see the overlay (asleep or locked).
    private var isUserAway: Bool { isSystemAsleep || isScreenLocked }

    var menuBarIconName: String {
        if isBreakPrompted { return "eye.trianglebadge.exclamationmark" }
        if isVideoPlaying { return "play.circle" }
        switch displayState {
        case .away, .meeting: return "eye.slash"
        default: return "eye"
        }
    }

    // MARK: - Init

    init(preview: Bool = false) {
        if preview {
            hasInputMonitoringPermission = true
            return
        }
        Log.i("Blink starting up")

        setupEngineCallbacks()
        loadTodayStats()
        BlinkLog.pruneOldLogs()

        // Sync sensitivity from UserDefaults
        let saved = UserDefaults.standard.double(forKey: "flowSensitivity")
        if saved > 0 { engine.sensitivity = saved }

        let savedWallClock = UserDefaults.standard.integer(forKey: "maxWallClockMinutes")
        if savedWallClock > 0 { engine.maxWallClockSeconds = TimeInterval(savedWallClock * 60) }

        if ThemeManager.shared.hasCompletedOnboarding {
            checkPermissionsAndStart()
        } else {
            Log.i("Onboarding not complete — deferring permissions")
            onboardingObserver = NotificationCenter.default.addObserver(
                forName: .onboardingCompleted, object: nil, queue: .main
            ) { [weak self] _ in
                Task { @MainActor in self?.onboardingCompleted() }
            }
        }
    }

    // MARK: - Engine Callbacks

    private func setupEngineCallbacks() {
        engine.onShowBreak = { [weak self] breakNumber in
            guard let self else { return }

            // If screen is locked or Mac is asleep, skip entirely.
            // Don't show overlay, don't record a break, don't reset the timer.
            // The engine tick is already suppressed by isUserAway, but this is
            // defense-in-depth in case a break was pending before sleep.
            if self.isUserAway {
                Log.i("Break due but user is away — suppressing (no overlay, no recording)")
                return
            }

            Log.i("Break #\(breakNumber) — showing overlay")
            self.isBreakPrompted = true
            self.overlayShownAt = Date()
            self.breaksPromptedToday += 1
            self.overlayController.showBreak(
                breakNumber: breakNumber,
                onComplete: { [weak self] in
                    Task { @MainActor in
                        Log.i("Break completed (countdown finished)")
                        self?.engine.userTookBreak()
                        self?.isBreakPrompted = false
                        self?.overlayShownAt = nil
                        self?.breaksTakenToday += 1
                        self?.overlayController.dismiss()
                    }
                },
                onSkip: { [weak self] in
                    Task { @MainActor in
                        Log.i("Break skipped")
                        self?.engine.userSkippedBreak()
                        self?.isBreakPrompted = false
                        self?.overlayShownAt = nil
                        self?.overlayController.dismiss()
                    }
                }
            )
        }

        engine.onShowExtendToast = { [weak self] reason in
            guard let self else { return }
            Log.i("Break decision: extend — \(reason)")
            self.overlayController.showFlowNudge(
                message: "\(reason) — extended 10 min",
                // e.g. "Focused — extended 10 min"
                onTakeBreak: { [weak self] in
                    Task { @MainActor in
                        self?.isBreakPrompted = false
                        self?.showBreakPrompt()
                    }
                }
            )
        }

        engine.onTimerUpdate = { [weak self] remaining, total in
            self?.remainingSeconds = remaining
            self?.timerTotal = total
        }

        engine.onStateChange = { [weak self] state in
            guard let self else { return }
            let prev = self.displayState
            if prev != state {
                Log.i("Engine state: \(prev) → \(state)")
            }
            self.displayState = state
        }

        engine.compliance.onBreakRecorded = { [weak self] record in
            Task { @MainActor in
                self?.persistence.saveBreakRecord(record)
            }
        }
    }

    // MARK: - Permissions & Monitoring

    func onboardingCompleted() {
        if let observer = onboardingObserver {
            NotificationCenter.default.removeObserver(observer)
            onboardingObserver = nil
        }
        checkPermissionsAndStart()
    }

    private func checkPermissionsAndStart() {
        let granted = PermissionManager.isPermissionGranted()
        Log.i("Permission probe result: \(granted)")
        if granted {
            hasInputMonitoringPermission = true
            UserDefaults.standard.set(true, forKey: "permissionGranted")
            // IM was already granted on a previous launch — go straight to
            // the mic step (which is a no-op if mic was also previously
            // resolved), then start monitoring.
            proceedToMicrophoneStep()
        } else {
            Log.i("Permission not granted — showing guide + firing system prompt")
            hasInputMonitoringPermission = false
            // Show our guide window FIRST so the user sees it regardless of
            // whether the OS Input Monitoring dialog ends up visible. The
            // guide window calls NSApp.activate(ignoringOtherApps:) on
            // present, which brings Blink to the foreground.
            showPermissionGuide()
            // Then fire the system prompt. A brief delay gives the guide
            // window time to render + activate the app, so the OS dialog
            // appears on top with focus instead of being silently presented
            // to an LSUIElement (menu-bar-only) app that's not foregrounded.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                NSApp.activate(ignoringOtherApps: true)
                PermissionManager.requestInputMonitoringAccess()
            }
        }
    }

    /// Re-shows the IM guide and, on grant, advances to the mic step
    /// (not directly to startMonitoring) — so we don't trigger the mic
    /// TCC prompt automatically as a side-effect of the engine first
    /// calling isMicrophoneActive(). `troubleshooting` switches to the
    /// "permission granted but tap dead" copy + actions for the
    /// cached-grant edge case.
    private func showPermissionGuide(troubleshooting: Bool = false) {
        permissionWindow = PermissionWindowController()
        permissionWindow?.show(
            theme: ThemeManager.shared.current,
            troubleshooting: troubleshooting
        ) { [weak self] in
            guard let self else { return }
            UserDefaults.standard.set(true, forKey: "permissionGranted")
            self.permissionWindow = nil
            self.hasInputMonitoringPermission = true
            Log.i("Input Monitoring granted — advancing to microphone step")
            self.proceedToMicrophoneStep()
        }
    }

    /// Second permission step: explainer dialog for microphone access.
    /// Skipped entirely if the user previously granted or denied (system
    /// remembers the decision). Engine starts only AFTER this resolves
    /// — granted, skipped, or no-op — so we never trigger the mic TCC
    /// prompt as an implicit side-effect of the tick timer.
    private func proceedToMicrophoneStep() {
        let status = PermissionManager.microphoneAuthorizationStatus()
        if status == .authorized || status == .denied || status == .restricted {
            Log.i("Microphone status already resolved (\(status.rawValue)) — skipping explainer")
            startMonitoringAfterAllPermissions()
            return
        }
        // status == .notDetermined — first time. Show our explainer.
        Log.i("Showing microphone permission explainer")
        micPermissionWindow = MicrophonePermissionWindowController()
        micPermissionWindow?.show(theme: ThemeManager.shared.current) { [weak self] granted in
            guard let self else { return }
            self.micPermissionWindow = nil
            Log.i("Microphone step resolved (granted=\(granted)) — starting monitors")
            self.startMonitoringAfterAllPermissions()
        }
    }

    /// Final step: actually start the engine. Called once all permissions
    /// (IM + mic) have been resolved one way or the other.
    private func startMonitoringAfterAllPermissions() {
        startMonitoring()
        startTimer()
        showTimerForStartup()
        Log.i("Monitors and timers started")
        verifyTapAliveOrReprompt()
    }

    /// Guards against the cached-grant silent-failure path:
    /// `PermissionManager.isPermissionGranted()` can return true when
    /// `CGPreflightListenEventAccess` returns true but `CGEvent.tapCreate`
    /// fails (typically TCC cache lag right after a grant, or a stale grant
    /// tied to a previous binary CDHash). `MacInputMonitor.startMonitoring`
    /// already retries internally up to 3 times with 1s delays; we wait 5s
    /// here to let those retries complete before deciding the tap is truly
    /// dead.
    ///
    /// If the tap is dead, we branch on the *current* preflight result:
    ///  - preflight = false → permission was revoked (or never really took);
    ///    show the standard grant guide
    ///  - preflight = true  → granted-but-broken (toggle didn't propagate to
    ///    this binary); show the troubleshooting guide instead of falsely
    ///    asking the user to grant something they already granted.
    private func verifyTapAliveOrReprompt() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
            guard let self else { return }
            if self.inputMonitor?.isTapAlive == true {
                Log.i("CGEventTap liveness verified 5s after startMonitoring")
                return
            }
            let preflight = CGPreflightListenEventAccess()
            Log.e("CGEventTap is not alive 5s after startMonitoring (preflight=\(preflight)) — reverting and reprompting")
            self.hasInputMonitoringPermission = false
            self.inputMonitor?.stopMonitoring()
            self.inputMonitor = nil
            self.tickTimer?.invalidate()
            self.tickTimer = nil
            self.overlayController.dismiss()
            self.showPermissionGuide(troubleshooting: preflight)
        }
    }

    private func startMonitoring() {
        Log.i("Starting input monitoring (CGEventTap)")
        let input = MacInputMonitor()
        input.onKeystroke = { [weak self] _ in self?.engine.recordKeystroke() }
        input.onMouseEvent = { [weak self] event in
            switch event.kind {
            case .click: self?.engine.recordClick()
            case .scroll(_): self?.engine.recordScroll()
            case .move(_, _): break
            }
        }
        input.startMonitoring()
        self.inputMonitor = input

        Log.i("Starting app monitor (NSWorkspace)")
        let appMon = MacAppMonitor()
        appMon.onAppSwitch = { [weak self] event in
            Log.d("App switch → \(event.appBundleID)")
            self?.engine.recordAppSwitch(bundleID: event.appBundleID)
        }
        appMon.startMonitoring()
        self.appMonitor = appMon

        // Dismiss overlay before Mac sleeps so it's never stuck on screen at wake
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Log.i("Mac going to sleep")
            guard let self else { return }
            self.isSystemAsleep = true
            if self.isBreakPrompted || self.overlayController.isShowingFullscreen {
                Log.i("Break overlay active before sleep — dismissing synchronously")
                self.engine.userSkippedBreak()
                self.isBreakPrompted = false
                self.overlayController.dismissImmediately()
            }
        }

        // Re-enable CGEventTap after Mac wakes from sleep
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Log.i("Wake from sleep")
            guard let self else { return }
            self.isSystemAsleep = false
            self.inputMonitor?.reEnableTapIfNeeded()
            // Defense-in-depth: if any overlay survived sleep, kill it immediately.
            if self.isBreakPrompted || self.overlayController.isShowingFullscreen {
                Log.i("Break overlay still present on wake — dismissing")
                self.engine.userSkippedBreak()
                self.isBreakPrompted = false
                self.overlayController.dismissImmediately()
            }
            self.engine.wakeFromSleep()
        }

        let ctx = MacContextDetector()
        ctx.onMicActiveAtLaunch = { [weak self] in
            DispatchQueue.main.async { self?.micAlwaysOnWarning = true }
        }
        self.contextDetector = ctx
        Log.i("All monitors active")

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            _ = self?.contextDetector?.isMicrophoneActive()
        }
    }

    private func startTimer() {
        tickTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                // Poll mic/camera/video every tick (cheap checks)
                let mic = self.contextDetector?.isMicrophoneActive() ?? false
                let cam = self.contextDetector?.isCameraActive() ?? false
                let video = self.contextDetector?.isMediaPlaying() ?? false
                self.engine.setMicActive(mic)
                self.engine.setCameraActive(cam)
                self.engine.setVideoPlaying(video)
                self.isVideoPlaying = video

                // If mic was flagged as "always on" at launch but is now inactive,
                // it was a meeting, not Dictation/Siri — clear the warning.
                if self.micAlwaysOnWarning && !mic {
                    self.micAlwaysOnWarning = false
                }

                // Tap health check + fallback polling
                self.inputMonitor?.reEnableTapIfNeeded()
                if self.inputMonitor?.isTapAlive != true {
                    self.pollInputFallback()
                    // If the tap is dead AND TCC now reports the permission as
                    // missing, the user revoked Input Monitoring while Blink
                    // was running. Reflect that in the menu bar banner so they
                    // see the issue + one-click path to re-grant — instead of
                    // silently running on the degraded HID-state fallback.
                    if self.hasInputMonitoringPermission && !CGPreflightListenEventAccess() {
                        Log.i("Permission revoked mid-session — surfacing banner")
                        self.hasInputMonitoringPermission = false
                    }
                }

                // Midnight reset — reload today's stats when the day rolls over
                let today = Calendar.current.component(.day, from: Date())
                if today != self.lastStatsDay {
                    Log.i("Day changed — resetting break counters")
                    self.lastStatsDay = today
                    self.loadTodayStats()
                }

                // Kill-switch: force-dismiss overlay if stuck beyond 2 minutes
                if let shownAt = self.overlayShownAt,
                   Date().timeIntervalSince(shownAt) >= Self.overlayMaxSeconds {
                    Log.e("Kill-switch: overlay stuck for >\(Int(Self.overlayMaxSeconds))s — force dismissing")
                    self.engine.userSkippedBreak()
                    self.isBreakPrompted = false
                    self.overlayShownAt = nil
                    self.overlayController.dismissImmediately()
                }

                if !self.isPaused && !self.isUserAway { self.engine.tick() }
            }
        }
    }

    // MARK: - Input fallback (when CGEventTap is dead — secure keyboard entry, etc.)

    /// Poll CGEventSource as a fallback when the tap can't receive events.
    /// This works even during secure keyboard entry because it reads from
    /// the kernel's HID state table, not from an event tap.
    private func pollInputFallback() {
        let threshold: TimeInterval = 1.0  // detect events within the last tick

        let keyIdle = CGEventSource.secondsSinceLastEventType(.hidSystemState, eventType: .keyDown)
        if keyIdle < threshold {
            engine.recordKeystroke()
        }

        let clickIdle = CGEventSource.secondsSinceLastEventType(.hidSystemState, eventType: .leftMouseDown)
        if clickIdle < threshold {
            engine.recordClick()
        }

        let scrollIdle = CGEventSource.secondsSinceLastEventType(.hidSystemState, eventType: .scrollWheel)
        if scrollIdle < threshold {
            engine.recordScroll()
        }
    }

    // MARK: - Menu bar

    private func showTimerForStartup() {
        findStatusItemAndOpen(attempts: 0)
    }

    private func findStatusItemAndOpen(attempts: Int) {
        guard attempts < 10 else {
            Log.i("MenuBarController: gave up finding status item after 10 attempts")
            return
        }
        let delay = 0.3 * Double(attempts + 1)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            MenuBarController.shared.findStatusItem()
            if MenuBarController.shared.statusItem != nil {
                Log.i("MenuBarController: found status item on attempt \(attempts + 1)")
                MenuBarController.shared.open()
            } else {
                self.findStatusItemAndOpen(attempts: attempts + 1)
            }
        }
    }

    // MARK: - Public actions (for menu bar buttons)

    func togglePause() {
        isPaused.toggle()
        Log.i("Pause toggled → \(isPaused ? "paused" : "resumed")")
    }

    func showBreakPrompt() {
        // Manual trigger from menu bar — skip the 3s toast and go directly to break
        let breakNum = engine.currentBreakStreak + 1
        Log.i("Manual break #\(breakNum) triggered from menu bar")
        isBreakPrompted = true
        overlayShownAt = Date()
        breaksPromptedToday += 1
        overlayController.showBreak(
            breakNumber: breakNum,
            skipToast: true,
            onComplete: { [weak self] in
                Task { @MainActor in
                    Log.i("Manual break #\(breakNum) completed (countdown finished)")
                    self?.engine.userTookBreak()
                    self?.isBreakPrompted = false
                    self?.overlayShownAt = nil
                    self?.breaksTakenToday += 1
                    self?.overlayController.dismiss()
                }
            },
            onSkip: { [weak self] in
                Task { @MainActor in
                    Log.i("Manual break #\(breakNum) skipped")
                    self?.engine.userSkippedBreak()
                    self?.isBreakPrompted = false
                    self?.overlayShownAt = nil
                    self?.overlayController.dismiss()
                }
            }
        )
    }

    // MARK: - Persistence

    private func loadTodayStats() {
        let records = persistence.loadTodayRecords()
        breaksPromptedToday = records.count
        breaksTakenToday = records.filter { $0.compliance == .taken || $0.compliance == .delayed }.count
        Log.i("Loaded today's stats: \(self.breaksTakenToday)/\(self.breaksPromptedToday) breaks taken")
    }
}
