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

    // Engine — constructed in init() with the effective sensitivity.
    public let engine: BlinkEngine

    // Platform monitors
    private var inputMonitor: MacInputMonitor?
    private var appMonitor: MacAppMonitor?
    private var contextDetector: MacContextDetector?
    private var permissionRecovery: InputMonitoringRecoveryWindowController?
    private var permissionFlow: PermissionFlowWindowController?
    private var launchHUD: LaunchHUDWindowController?
    private var simpleModeAnnouncement: SimpleModeAnnouncementWindowController?

    // NSWorkspace sleep/wake observer tokens. Stashed so teardownMonitoring()
    // can remove them on detection-mode hot-swap — otherwise every swap
    // accumulates another pair of callbacks.
    private var sleepObserver: NSObjectProtocol?
    private var wakeObserver: NSObjectProtocol?

    // Timers
    private var tickTimer: Timer?
    /// Counts engine ticks since the last input-rate log line. The tick fires
    /// every 1s; we report input counts every 30 ticks (30s) so the log has
    /// a periodic pulse confirming events are flowing without flooding.
    private var ticksSinceLastInputReport: Int = 0
    private static let inputReportTickInterval: Int = 30

    // Sleep / lock tracking — used to suppress overlay when user is away
    private var isSystemAsleep = false

    // Kill-switch: hard timeout if overlay is stuck beyond any reasonable duration
    private var overlayShownAt: Date?
    private static let overlayMaxSeconds: TimeInterval = 120

    // Day tracking — reset break counters at midnight
    private var lastStatsDay: Int = Calendar.current.component(.day, from: Date())

    // Sedentary tracking — wall-clock since the user was last continuously
    // idle for sedentaryResetThreshold seconds (i.e. since they actually
    // got up). Feeds BreakSuggestionPicker. Initialized at launch so a freshly
    // launched user looks "just got back to the desk" rather than instantly
    // sedentary.
    private var lastMovementAt: Date = Date()
    private var wasIdleLastTick: Bool = false
    /// Min idle (seconds) that counts as "they got up". Matches the
    /// 90s idleBreakThreshold elsewhere in the codebase plus 30s slack.
    private static let sedentaryResetThreshold: TimeInterval = 120

    // Last suggestion shown — used by BreakSuggestionPicker's novelty filter
    // to avoid two identical suggestions back-to-back. In-memory only;
    // resetting on app restart is fine.
    private var lastBreakSuggestion: BreakSuggestion?

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
        // Construct the engine with the effective sensitivity — either the
        // persisted user value or the canonical UI default. BlinkCore has
        // no internal default; this is the only source of truth.
        let savedSensitivity = UserDefaults.standard.double(forKey: "flowSensitivity")
        let effectiveSensitivity = savedSensitivity > 0
            ? savedSensitivity
            : FlowSensitivityView.Preset.balanced.value
        self.engine = BlinkEngine(sensitivity: effectiveSensitivity)

        if preview {
            hasInputMonitoringPermission = true
            return
        }
        Log.i("Blink starting up")

        setupEngineCallbacks()
        loadTodayStats()
        BlinkLog.pruneOldLogs()

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
            let suggestion = self.pickBreakSuggestion()
            self.overlayController.showBreak(
                breakNumber: breakNumber,
                suggestion: suggestion,
                onComplete: { [weak self] in
                    Task { @MainActor in
                        Log.i("Break completed (countdown finished)")
                        self?.engine.userTookBreak()
                        self?.isBreakPrompted = false
                        self?.overlayShownAt = nil
                        self?.breaksTakenToday += 1
                        self?.overlayController.dismiss()
                        self?.playBreakEndChime()
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

    /// Called the moment onboarding finishes (theme + flow sensitivity
    /// only — the permission flow is presented separately). Same code
    /// path as checkPermissionsAndStart for already-onboarded users
    /// because the decision tree is identical: IM granted → start;
    /// basicModeOptIn → start basic; else surface the permission flow.
    func onboardingCompleted() {
        if let observer = onboardingObserver {
            NotificationCenter.default.removeObserver(observer)
            onboardingObserver = nil
        }
        // Fresh users just saw the InputMonitoringPermissionPage with its
        // "Use Simple timer mode" CTA — they don't need a "did you know?"
        // HUD about a choice they just made. Pre-set the announced flag so
        // maybeShowSimpleModeAnnouncement skips them.
        UserDefaults.standard.set(true, forKey: "simpleModeAnnounced")
        Log.i("Onboarding completed (theme + flow) — running permission check")
        checkPermissionsAndStart(cameFromOnboarding: true)
    }

    /// Decides what to do once onboarding (theme + flow) is recorded as
    /// complete. Three branches:
    ///   - IM granted              → start the smart engine
    ///   - basicModeOptIn          → start the basic-timer fallback
    ///   - Neither, and never previously granted   → show PermissionFlow
    ///     (first-time mic + IM setup)
    ///   - Neither, but previously granted (IM revoked / stale grant
    ///     after a binary update) → show the staleGrant recovery window
    private func checkPermissionsAndStart(cameFromOnboarding: Bool = false) {
        let granted = PermissionManager.isPermissionGranted()
        let micStatus = PermissionManager.microphoneAuthorizationStatus()
        let basicModeOptIn = UserDefaults.standard.bool(forKey: "basicModeOptIn")
        let previouslyGranted = UserDefaults.standard.bool(forKey: "permissionGranted")
        Log.i("Permission probe: IM=\(granted), mic=\(micStatus.rawValue), basicModeOptIn=\(basicModeOptIn), prevGranted=\(previouslyGranted)")

        // basicModeOptIn wins over the OS-level IM grant. A user who
        // deliberately chose Simple — and then either clicked "Leave it
        // granted" on the revoke alert OR didn't revoke yet — would
        // otherwise be silently flipped back to Smart here on every
        // launch. That destroys the explicit choice. The only way OUT
        // of Simple mode is the Settings → Flow → Detection Mode picker
        // (which clears basicModeOptIn via setDetectionMode(smart: true)).
        if basicModeOptIn {
            Log.i("Basic mode opt-in remembered — starting basic-timer fallback (IM=\(granted))")
            hasInputMonitoringPermission = false
            // Reflect any prior IM grant in permissionGranted so the
            // future smart→simple→smart path skips PermissionFlow.
            if granted { UserDefaults.standard.set(true, forKey: "permissionGranted") }
            startMonitoringAfterAllPermissions()
            return
        }

        if granted {
            hasInputMonitoringPermission = true
            UserDefaults.standard.set(true, forKey: "permissionGranted")
            startMonitoringAfterAllPermissions()
            return
        }

        // No IM, no basic-mode opt-in. Two sub-cases distinguished by
        // whether IM was EVER granted before:
        //   - previouslyGranted=true  → stale grant (binary changed,
        //                                TCC cache pointing at old CDHash)
        //                                → recovery window with .staleGrant copy
        //   - previouslyGranted=false → first-time setup (just finished
        //                                onboarding or restart interrupted
        //                                the original permission flow)
        //                                → PermissionFlow (mic + IM)
        hasInputMonitoringPermission = false
        if previouslyGranted {
            Log.i("IM revoked post-grant — showing staleGrant recovery window")
            showRecoveryWindow()
        } else {
            Log.i("No IM yet — showing first-time PermissionFlow window")
            showPermissionFlow(forceLight: cameFromOnboarding)
        }
    }

    /// Shows the first-time mic + IM permission flow. Used after a fresh
    /// onboarding completes, and on any subsequent launch where the user
    /// hasn't yet granted IM and hasn't opted into basic mode (e.g. a
    /// TCC restart mid-permission-grant put us back here on relaunch).
    ///
    /// `forceLight` is true only when this immediately follows onboarding —
    /// onboarding is forced light, so the permission flow stays light to avoid
    /// a light→dark jump mid-flow. Standalone launches (and the Settings
    /// simple→smart path) pass false to honor the system appearance.
    /// - forceLight: keep the window light to match forced-light onboarding
    ///   (true only when shown straight after onboarding).
    /// - startAtPermissions: skip the detection-mode choice page and land on
    ///   the mic/IM steps directly. True when the user already chose Smart in
    ///   Settings → Flow, so re-showing the choice would be redundant.
    private func showPermissionFlow(forceLight: Bool = false, startAtPermissions: Bool = false) {
        permissionFlow = PermissionFlowWindowController()
        permissionFlow?.show(
            theme: ThemeManager.shared.current,
            forceLight: forceLight,
            startAtPermissions: startAtPermissions,
            onResolved: { [weak self] basicMode in
                guard let self else { return }
                self.permissionFlow = nil
                if basicMode {
                    Log.i("PermissionFlow resolved via skip — entering basic mode")
                    self.enterSimpleModeAndStart(announceLaunch: true)
                    // Offer the revoke step if the OS still holds an IM grant.
                    self.maybeOfferToRevokeIMGrant(trigger: "PermissionFlow skip")
                } else {
                    Log.i("PermissionFlow resolved — IM granted")
                    UserDefaults.standard.set(true, forKey: "permissionGranted")
                    UserDefaults.standard.set(false, forKey: "basicModeOptIn")
                    self.hasInputMonitoringPermission = true
                    self.startMonitoringAfterAllPermissions()
                }
            },
            onClose: { [weak self] in
                guard let self else { return }
                self.permissionFlow = nil
                Log.i("PermissionFlow closed without choosing — defaulting to Simple timer mode")
                self.enterSimpleModeAndStart(announceLaunch: false)
                self.maybeOfferToRevokeIMGrant(trigger: "PermissionFlow close")
                self.showSimpleModeActiveHUD()
            }
        )
    }

    // MARK: - Detection mode switching (Settings-driven)

    /// Public entry point for the Settings → Detection mode picker.
    /// Handles all four transitions (smart→smart, simple→simple,
    /// smart→simple, simple→smart). For simple→smart without IM granted,
    /// presents the PermissionFlow window so the user can grant it.
    func setDetectionMode(smart: Bool) {
        // Resolve any active break overlay BEFORE tearing down monitors.
        // Otherwise the engine's break-state stays "prompted", the tick
        // timer that would auto-dismiss is killed, and the overlay
        // hangs until kill-switch (or forever if the new tick doesn't
        // run the same guard). Treat a mode switch as a user-skip.
        if isBreakPrompted || overlayController.isShowingFullscreen {
            Log.i("Detection-mode switch while break overlay active — treating as user-skip")
            engine.userSkippedBreak()
            isBreakPrompted = false
            overlayController.dismissImmediately()
        }

        if smart {
            // simple → smart
            let granted = PermissionManager.isPermissionGranted()
            if granted {
                Log.i("Settings: switching simple → smart (IM already granted)")
                UserDefaults.standard.set(false, forKey: "basicModeOptIn")
                UserDefaults.standard.set(true, forKey: "permissionGranted")
                hasInputMonitoringPermission = true
                teardownMonitoring()
                startMonitoring()
                startTimer()
                verifyTapAliveOrReprompt()
            } else {
                // No IM grant yet. The user already chose Smart in Settings,
                // so skip the detection-mode choice page and land directly on
                // the mic/IM permission steps. Honor system appearance (not an
                // onboarding follow-up).
                Log.i("Settings: switching simple → smart (need to request IM) — showing PermissionFlow at permissions")
                showPermissionFlow(forceLight: false, startAtPermissions: true)
            }
        } else {
            // smart → simple (or simple → simple, idempotent)
            Log.i("Settings: switching to simple timer mode")
            UserDefaults.standard.set(true, forKey: "basicModeOptIn")
            UserDefaults.standard.set(false, forKey: "permissionGranted")
            hasInputMonitoringPermission = false
            teardownMonitoring()
            startMonitoring()
            startTimer()
            maybeOfferToRevokeIMGrant(trigger: "Settings picker")
        }
    }

    /// If the user opted into Simple timer mode but the macOS TCC grant
    /// for Input Monitoring is still present, offer to help them revoke
    /// it from System Settings. Without this, "Simple" is a half-measure:
    /// Blink stops *using* the permission but the OS still considers
    /// Blink permitted to monitor input — and a future toggle back to
    /// Smart would silently re-acquire the tap without a fresh prompt.
    ///
    /// Guards on `CGPreflightListenEventAccess()` so the dialog never
    /// fires when there's nothing to revoke (e.g. user opted into Simple
    /// during onboarding without ever granting IM).
    func maybeOfferToRevokeIMGrant(trigger: String) {
        guard CGPreflightListenEventAccess() else {
            Log.i("Simple-mode revoke-offer (\(trigger)): IM not granted at OS level — skipping")
            return
        }
        Log.i("Simple-mode revoke-offer (\(trigger)): OS still has IM grant — prompting user")

        let alert = NSAlert()
        alert.messageText = "Simple timer mode is on"
        alert.informativeText = """
        Blink will no longer use Input Monitoring. The macOS permission, though, is still granted in System Settings — Blink could re-enable it without prompting you again.

        For a full privacy reset, also remove Blink from System Settings → Privacy & Security → Input Monitoring.
        """
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Leave it granted")
        alert.alertStyle = .informational

        // Ensure the alert sits in front of any other Blink window
        // (Settings, menu bar popover). Activating first because alerts
        // attached to a non-active app can render behind frontmost apps.
        NSApp.activate(ignoringOtherApps: true)

        // Prefer sheet-attachment when there's a key window (the Settings
        // window when invoked from the picker, the recovery window when
        // invoked from PermissionFlow). Sheet-attach is non-blocking and
        // doesn't freeze the parent UI. Fall back to app-modal `runModal`
        // only when no window is in front (e.g. invoked headlessly).
        let handler: (NSApplication.ModalResponse) -> Void = { response in
            if response == .alertFirstButtonReturn {
                UIActionLogger.buttonTapped("Open System Settings (revoke IM)", context: trigger)
                PermissionManager.openInputMonitoringSettings()
            } else {
                UIActionLogger.buttonTapped("Leave IM granted", context: trigger)
            }
        }
        if let keyWindow = NSApp.keyWindow {
            alert.beginSheetModal(for: keyWindow, completionHandler: handler)
        } else {
            handler(alert.runModal())
        }
    }

    /// Shows the recovery window for the cached-grant / revoked case —
    /// the same InputMonitoringPermissionPage used in onboarding, with
    /// its `.staleGrant` mode that swaps the header copy to "Permission
    /// Granted — But Not Working" + the toggle-off-then-on guidance.
    private func showRecoveryWindow() {
        permissionRecovery = InputMonitoringRecoveryWindowController()
        permissionRecovery?.show(
            theme: ThemeManager.shared.current,
            onResolved: { [weak self] basicMode in
                guard let self else { return }
                self.permissionRecovery = nil
                if basicMode {
                    // User clicked "Continue with basic timer" — opted out of
                    // smart mode for now. Persisted as basicModeOptIn=true so
                    // future launches don't keep re-popping the recovery
                    // window. The opt-in is automatically cleared the next
                    // time IM is actually granted (see checkPermissionsAndStart).
                    Log.i("Recovery dismissed via skip — entering basic mode")
                    self.enterSimpleModeAndStart(announceLaunch: true)
                    // The recovery window appears specifically because IM was
                    // previously granted (stale CDHash), so the OS grant is
                    // almost certainly still present — offer the revoke step.
                    self.maybeOfferToRevokeIMGrant(trigger: "Recovery skip")
                } else {
                    Log.i("Recovery resolved — IM re-granted")
                    UserDefaults.standard.set(true, forKey: "permissionGranted")
                    UserDefaults.standard.set(false, forKey: "basicModeOptIn")
                    self.hasInputMonitoringPermission = true
                    self.startMonitoringAfterAllPermissions()
                }
            },
            onClose: { [weak self] in
                guard let self else { return }
                self.permissionRecovery = nil
                Log.i("Recovery closed without choosing — defaulting to Simple timer mode")
                self.enterSimpleModeAndStart(announceLaunch: false)
                self.maybeOfferToRevokeIMGrant(trigger: "Recovery close")
                self.showSimpleModeActiveHUD()
            }
        )
    }

    /// Idempotent: tears down any existing monitors/timer first, then
    /// starts fresh. Callable on first launch, after onboarding completes,
    /// and on recovery (e.g. user re-granted IM after seeing the
    /// staleGrant window). The launch HUD shows on every path — it's the
    /// "Blink is running, here's where to find it" prompt.
    private func startMonitoringAfterAllPermissions(announceLaunch: Bool = true) {
        teardownMonitoring()
        startMonitoring()
        startTimer()
        // The close→Simple path shows its own "Simple mode is active" HUD, so
        // it suppresses the generic launch HUD to avoid two HUDs stacking in
        // the same top-right corner.
        if announceLaunch { showLaunchHUD() }
        Log.i("Monitors and timers started")
        verifyTapAliveOrReprompt()
    }

    /// Persists Simple-mode opt-in and (re)starts the runtime in Simple mode.
    /// Shared by the explicit "Use Simple timer mode" choice and the
    /// close-without-choosing default. `announceLaunch` is false for the close
    /// path, which shows its own confirming HUD instead.
    private func enterSimpleModeAndStart(announceLaunch: Bool) {
        UserDefaults.standard.set(true, forKey: "basicModeOptIn")
        UserDefaults.standard.set(false, forKey: "permissionGranted")
        hasInputMonitoringPermission = false
        startMonitoringAfterAllPermissions(announceLaunch: announceLaunch)
    }

    /// Shows the "Simple timer mode is on" confirmation HUD after the user
    /// closed a setup window without choosing. "Open Preferences" deep-links to
    /// the Flow tab where the detection-mode picker lives.
    private func showSimpleModeActiveHUD() {
        simpleModeAnnouncement = SimpleModeAnnouncementWindowController()
        simpleModeAnnouncement?.show(
            theme: ThemeManager.shared.current,
            style: .activeByDefault,
            onShowMe: { [weak self] in
                self?.simpleModeAnnouncement = nil
                self?.openPreferences(initialTab: 2)  // Flow
            },
            onDismiss: { [weak self] in
                self?.simpleModeAnnouncement = nil
            }
        )
    }

    /// Stop any running monitors + timer so startMonitoringAfterAllPermissions
    /// can be called again safely (without leaking the prior CGEventTap,
    /// NSWorkspace observer, context detector, or tick Timer).
    private func teardownMonitoring() {
        inputMonitor?.stopMonitoring()
        inputMonitor = nil
        appMonitor?.stopMonitoring()
        appMonitor = nil
        // MacContextDetector has no lifecycle methods — just drop the
        // reference. The cheap polling it does via the tick timer stops
        // automatically once tickTimer is invalidated below.
        contextDetector = nil
        tickTimer?.invalidate()
        tickTimer = nil

        // Remove the sleep/wake observers added in startMonitoring().
        // Without this, every detection-mode hot-swap accumulates another
        // observer pair — N swaps → N+1 callbacks per wake.
        if let token = sleepObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(token)
            sleepObserver = nil
        }
        if let token = wakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(token)
            wakeObserver = nil
        }
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
        // In basic mode there's no MacInputMonitor to verify — pollInputFallback
        // is the intended path. Skip the watchdog so we don't false-flag a
        // "missing tap" and bounce the user back into the permission wizard.
        guard hasInputMonitoringPermission else { return }
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
            self.showRecoveryWindow()
        }
    }

    private func startMonitoring() {
        if hasInputMonitoringPermission {
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
        } else {
            Log.i("Basic mode: skipping CGEventTap (no Input Monitoring permission)")
            // inputMonitor stays nil. The engine still ticks every 30s and
            // pollInputFallback (CGEventSource.secondsSinceLastEventType,
            // no permission required) provides sparse keystroke/click
            // signals from the kernel HID state — so timer countdown and
            // idle detection still work, just without the rich event
            // stream needed for flow scoring.
        }

        Log.i("Starting app monitor (NSWorkspace)")
        let appMon = MacAppMonitor()
        appMon.onAppSwitch = { [weak self] event in
            Log.d("App switch → \(event.appBundleID)")
            self?.engine.recordAppSwitch(bundleID: event.appBundleID)
        }
        appMon.startMonitoring()
        self.appMonitor = appMon

        // Seed the currently-frontmost app at startup.
        // NSWorkspace.didActivateApplicationNotification only fires on app
        // CHANGES, not for the app that's already frontmost. Without this
        // seed call, a user who launches Blink while Xcode is the active
        // app and then never switches apps produces zero appSwitch events
        // — and the engine's dwellByApp stays empty → creative bonus
        // silently drops from 0.10 → 0.03 for the entire first window.
        if let frontmostID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier {
            Log.i("Seeding initial frontmost app: \(frontmostID)")
            engine.setCurrentApp(bundleID: frontmostID)
        } else {
            Log.i("No frontmost app at startup — dwell tracking will start on first app switch")
        }

        // Dismiss overlay before Mac sleeps so it's never stuck on screen at wake.
        // queue: .main guarantees we're on the main thread; MainActor.assumeIsolated
        // tells Swift's actor-isolation checker so we can touch @MainActor state.
        // Tokens are stashed so teardownMonitoring() can remove them — without
        // this, every detection-mode hot-swap leaks another observer pair and
        // wake/sleep callbacks multiply.
        sleepObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
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
        }

        // Re-enable CGEventTap after Mac wakes from sleep
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
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

                // Sedentary tracking — detect the rising edge from
                // "idle ≥ threshold" back to "active again", which is when
                // the user has actually returned to the desk. Reset baseline
                // then so BreakSuggestionPicker.sedentarySeconds counts from
                // that moment forward. CGEventSource.secondsSinceLastEventType
                // (hidSystemState) needs no permission — works in Simple mode too.
                let keyIdle = CGEventSource.secondsSinceLastEventType(.hidSystemState, eventType: .keyDown)
                let clickIdle = CGEventSource.secondsSinceLastEventType(.hidSystemState, eventType: .leftMouseDown)
                let minIdle = min(keyIdle, clickIdle)
                let isIdleNow = minIdle >= Self.sedentaryResetThreshold
                if self.wasIdleLastTick && !isIdleNow {
                    self.lastMovementAt = Date()
                }
                self.wasIdleLastTick = isIdleNow

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

                // Periodic input-rate report so logs have a heartbeat
                // confirming events are flowing. Logs only when there was
                // any activity in the window — silent if user is away.
                //
                // In Simple mode there's no inputMonitor, so the smart-mode
                // branch is permanently silent. Emit a parallel heartbeat
                // using the same source pollInputFallback feeds the engine
                // from (.hidSystemState) so the log reflects what the engine
                // actually sees — frontmost app + idle seconds + away/pause
                // flags + timer remaining. Fires every tick interval whether
                // or not there was activity (idle is the interesting signal
                // here, not just presence).
                self.ticksSinceLastInputReport += 1
                if self.ticksSinceLastInputReport >= Self.inputReportTickInterval {
                    self.ticksSinceLastInputReport = 0
                    if let counts = self.inputMonitor?.drainCounts(),
                       counts.keystrokes + counts.mouseMoves + counts.scrolls + counts.clicks > 0 {
                        Log.i("Input (last \(Self.inputReportTickInterval)s): keystrokes=\(counts.keystrokes), mouseMoves=\(counts.mouseMoves), scrolls=\(counts.scrolls), clicks=\(counts.clicks)")
                    } else if self.inputMonitor == nil {
                        let keyIdle = CGEventSource.secondsSinceLastEventType(.hidSystemState, eventType: .keyDown)
                        let clickIdle = CGEventSource.secondsSinceLastEventType(.hidSystemState, eventType: .leftMouseDown)
                        let scrollIdle = CGEventSource.secondsSinceLastEventType(.hidSystemState, eventType: .scrollWheel)
                        let idle = Int(min(keyIdle, min(clickIdle, scrollIdle)))
                        let app = NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "?"
                        let remaining = Int(self.remainingSeconds)
                        Log.i("Simple tick: idle=\(idle)s frontmost=\(app) away=\(self.isUserAway) paused=\(self.isPaused) remaining=\(remaining)s")
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

    // MARK: - Launch HUD

    /// Shows a brief themed HUD at the top-right of the screen on launch
    /// to confirm Blink is running. Replaces the previous "auto-open the
    /// menu bar popup" approach — that couldn't surface anything when the
    /// user's menu bar icon was hidden behind the notch / Bartender / or
    /// pushed off-screen by sheer menu bar overflow. The HUD is its own
    /// floating window so it's always visible regardless of menu bar state.
    /// Shows the persistent launch HUD on every launch. "I've found it"
    /// dismisses it; "Can't find it" opens the help dialog, which explains
    /// the notch/overflow problem and offers a guaranteed fallback entry
    /// point (Open Preferences).
    private func showLaunchHUD() {
        launchHUD = LaunchHUDWindowController()
        launchHUD?.show(
            theme: ThemeManager.shared.current,
            onFound: { [weak self] in self?.maybeShowSimpleModeAnnouncement() },
            onCantFind: { [weak self] in
                MenuBarHelpWindowController.shared.show {
                    self?.openPreferences()
                }
            }
        )
    }

    /// One-time HUD telling existing Smart-mode users that Simple timer
    /// mode is now an option. Trigger conditions:
    ///   - User has already granted IM (i.e. they're a pre-existing Smart
    ///     user, not a fresh install that's just gone through onboarding)
    ///   - `simpleModeAnnounced` flag not yet set
    /// Defers 1.2s so the launch HUD has a clean dismissal before this
    /// HUD pops up in the same screen corner.
    private func maybeShowSimpleModeAnnouncement() {
        let announced = UserDefaults.standard.bool(forKey: "simpleModeAnnounced")
        guard !announced else { return }
        guard hasInputMonitoringPermission else {
            // No IM at runtime — two sub-cases:
            //   - deliberate Simple (basicModeOptIn=true): user has
            //     already made the choice, no need to announce. Mark
            //     announced so they don't see the HUD if they later
            //     re-enable Smart.
            //   - stale/revoked IM (basicModeOptIn=false): the user is
            //     in basic mode INCIDENTALLY and would WANT to see the
            //     HUD as soon as they recover IM. Leave the flag alone.
            if UserDefaults.standard.bool(forKey: "basicModeOptIn") {
                UserDefaults.standard.set(true, forKey: "simpleModeAnnounced")
            } else {
                Log.i("Skipping Simple-mode announcement HUD this launch — IM not granted yet, leaving flag for next time")
            }
            return
        }
        Log.i("Showing one-time Simple-mode announcement HUD")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            guard let self else { return }
            self.simpleModeAnnouncement = SimpleModeAnnouncementWindowController()
            self.simpleModeAnnouncement?.show(
                theme: ThemeManager.shared.current,
                onShowMe: { [weak self] in
                    guard let self else { return }
                    UserDefaults.standard.set(true, forKey: "simpleModeAnnounced")
                    // Land on Flow tab where the detection mode picker
                    // lives — that's the "show me" the user just asked for.
                    PreferencesWindowController.shared.show(
                        appState: self,
                        themeManager: ThemeManager.shared,
                        initialTab: 2
                    )
                    self.simpleModeAnnouncement = nil
                },
                onDismiss: { [weak self] in
                    UserDefaults.standard.set(true, forKey: "simpleModeAnnounced")
                    self?.simpleModeAnnouncement = nil
                }
            )
        }
    }

    /// Opens the Preferences window. Called from the launch HUD tap so
    /// the user has somewhere obvious to land if they can't find the menu
    /// bar icon. `initialTab` deep-links to a tab (0=General, 1=Theme,
    /// 2=Flow, 3=About) — honored only when the window isn't already open.
    func openPreferences(initialTab: Int = 0) {
        PreferencesWindowController.shared.show(appState: self, themeManager: ThemeManager.shared, initialTab: initialTab)
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
        let suggestion = pickBreakSuggestion()
        overlayController.showBreak(
            breakNumber: breakNum,
            suggestion: suggestion,
            skipToast: true,
            onComplete: { [weak self] in
                Task { @MainActor in
                    Log.i("Manual break #\(breakNum) completed (countdown finished)")
                    self?.engine.userTookBreak()
                    self?.isBreakPrompted = false
                    self?.overlayShownAt = nil
                    self?.breaksTakenToday += 1
                    self?.overlayController.dismiss()
                    self?.playBreakEndChime()
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

    // MARK: - Break-End Chime

    private func playBreakEndChime() {
        let defaults = UserDefaults.standard
        // Default-on: only treat an explicit `false` as muted; missing key = enabled.
        let enabled = (defaults.object(forKey: "chimeEnabled") as? Bool) ?? true
        guard enabled else { return }
        let id = defaults.string(forKey: "chimeID") ?? ChimePlayer.defaultChimeID
        let volume = (defaults.object(forKey: "chimeVolume") as? Double) ?? ChimePlayer.defaultVolume
        Log.i("Playing break-end chime: \(id) at \(Int(volume * 100))%")
        ChimePlayer.shared.play(id: id, volume: volume)
    }

    // MARK: - Break suggestion

    /// Build the picker context from current state and pick a suggestion.
    /// Side effect: updates `lastBreakSuggestion` so the next break's
    /// novelty filter has the right input.
    private func pickBreakSuggestion() -> BreakSuggestion {
        let sedentary = Date().timeIntervalSince(lastMovementAt)
        let hour = Calendar.current.component(.hour, from: Date())

        // Count noncompliance in the last 3 records of today.
        let recent = persistence.loadTodayRecords().suffix(3)
        let noncompliant = recent.filter { rec in
            switch rec.compliance {
            case .dismissed, .ignored: return true
            case .taken, .delayed:     return false
            }
        }.count

        // `wasInFlow` is true when the engine extended the timer at least
        // once before deciding to break — proxy for "user was in sustained
        // flow." Reading from spotCheck because BlinkEngine doesn't expose
        // FlowState directly.
        let wasInFlow = engine.spotCheckFlow().extensionCount >= 1

        let ctx = BreakSuggestionContext(
            sedentarySeconds: sedentary,
            wasInFlow: wasInFlow,
            hourOfDay: hour,
            recentNoncompliance: noncompliant,
            lastSuggestion: lastBreakSuggestion
        )
        let picked = BreakSuggestionPicker.pick(ctx)
        Log.i("Break suggestion: \(picked.rawValue) "
            + "(sedentary=\(Int(sedentary))s, wasInFlow=\(wasInFlow), "
            + "hour=\(hour), nonCompliance=\(noncompliant)/3)")
        lastBreakSuggestion = picked
        return picked
    }

    // MARK: - Persistence

    private func loadTodayStats() {
        let records = persistence.loadTodayRecords()
        breaksPromptedToday = records.count
        breaksTakenToday = records.filter { $0.compliance == .taken || $0.compliance == .delayed }.count
        Log.i("Loaded today's stats: \(self.breaksTakenToday)/\(self.breaksPromptedToday) breaks taken")
    }
}
