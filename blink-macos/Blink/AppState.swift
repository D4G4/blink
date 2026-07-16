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
    /// How the current manual pause ends. `nil` == running normally.
    /// Drives the auto-resume logic; `isPaused` is derived from it so every
    /// existing read site keeps working unchanged.
    @Published var pauseMode: PauseMode? = nil
    /// Frontmost non-Blink app, tracked continuously so the "pause while
    /// <App> is open" menu item and its resume check always have a real
    /// target — even while Blink's own menu popover is frontmost.
    @Published private(set) var lastActiveAppID: String?
    @Published private(set) var lastActiveAppName: String?
    @Published var micAlwaysOnWarning: Bool = false

    /// An Auto-Pause feature the user has ON but whose OS permission is missing,
    /// so the feature silently can't work. Surfaced as a menu-bar attention
    /// badge + a menu row so the user isn't left thinking it's working.
    enum PermissionAlert: String, Identifiable, CaseIterable {
        case microphone, calendar
        var id: String { rawValue }
        /// Short line for the menu attention row.
        var menuText: String {
            switch self {
            case .microphone: return "Microphone access is off"
            case .calendar:   return "Calendar access is off"
            }
        }
    }
    @Published private(set) var permissionAlerts: [PermissionAlert] = []

    /// Re-evaluate which enabled Auto-Pause features are missing their OS
    /// permission. Cheap (local TCC queries); call on launch, app activation,
    /// and when the relevant toggles change. Only flags an *explicit* denial —
    /// `.notDetermined` (e.g. a user who skipped the mic step) isn't nagged.
    func refreshPermissionAlerts() {
        guard !isPreview else { permissionAlerts = []; return }
        var alerts: [PermissionAlert] = []
        let micOn = (UserDefaults.standard.object(forKey: "pauseDuringCalls") as? Bool) ?? true
        if micOn && PermissionManager.microphoneAuthorizationStatus() == .denied {
            alerts.append(.microphone)
        }
        // Calendar can only be ON if access was granted at enable-time, so any
        // non-fullAccess state now means it was revoked.
        let calendarOn = UserDefaults.standard.bool(forKey: "pauseDuringCalendarEvents")
        if calendarOn && PermissionManager.calendarAuthorizationStatus() != .fullAccess {
            alerts.append(.calendar)
        }
        if alerts != permissionAlerts { permissionAlerts = alerts }
    }

    #if DEBUG
    /// Preview/snapshot seam to seed `permissionAlerts` (which is otherwise
    /// private-set and cleared in preview mode).
    func setPermissionAlertsForPreview(_ alerts: [PermissionAlert]) {
        permissionAlerts = alerts
    }
    #endif

    @AppStorage("debugNotifications") var debugNotifications: Bool = false

    // Engine — constructed in init() with the effective sensitivity.
    public let engine: BlinkEngine

    // Platform monitors
    private var inputMonitor: MacInputMonitor?
    private var appMonitor: MacAppMonitor?
    private var contextDetector: MacContextDetector?
    /// EventKit-backed calendar watcher. nil unless the user has enabled
    /// "Pause during meetings" AND granted calendar access.
    private var calendarMonitor: MacCalendarMonitor?
    /// Coalesces `.EKEventStoreChanged` bursts (CalDAV syncs fire many in a
    /// row) into a single trailing re-evaluation so we don't run repeated
    /// synchronous EventKit queries on the main thread.
    private var calendarChangeDebounce: DispatchWorkItem?
    private var permissionRecovery: InputMonitoringRecoveryWindowController?
    private var permissionFlow: PermissionFlowWindowController?
    private var launchHUD: LaunchHUDWindowController?
    private var simpleModeAnnouncement: SimpleModeAnnouncementWindowController?
    private var whatsNewController: WhatsNewWindowController?

    // NSWorkspace sleep/wake observer tokens. Stashed so teardownMonitoring()
    // can remove them on detection-mode hot-swap — otherwise every swap
    // accumulates another pair of callbacks.
    private var sleepObserver: NSObjectProtocol?
    private var wakeObserver: NSObjectProtocol?
    // DistributedNotificationCenter screen lock/unlock tokens. Mirrors the
    // sleep/wake pattern. Screen lock without display sleep has no
    // NSWorkspace event — these are the only signal the OS gives us.
    private var screenLockObserver: NSObjectProtocol?
    private var screenUnlockObserver: NSObjectProtocol?

    // Timers
    private var tickTimer: Timer?
    /// Counts engine ticks since the last input-rate log line. The tick fires
    /// every 1s; we report input counts every 30 ticks (30s) so the log has
    /// a periodic pulse confirming events are flowing without flooding.
    private var ticksSinceLastInputReport: Int = 0
    private static let inputReportTickInterval: Int = 30
    /// Counts ticks since the last calendar evaluation. Calendar queries are
    /// heavier than the mic/cam poll, so we run them every 30s (not every
    /// tick); `.EKEventStoreChanged` triggers an extra immediate evaluation.
    private var ticksSinceCalendarCheck: Int = 0
    private static let calendarCheckTickInterval: Int = 30
    /// How far before a link-less event starts to offer the pause suggestion,
    /// so the user has time to interact with the toast before the meeting.
    static let calendarSuggestionLead: TimeInterval = 120  // 2 min
    /// Monitor look-ahead — must exceed `calendarSuggestionLead` so an upcoming
    /// event is fetched in time to suggest before it starts (extra margin
    /// covers the 30s evaluation throttle).
    private static let calendarLookAhead: TimeInterval = 180

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
    /// App-activation observer that refreshes `permissionAlerts` (lives for the
    /// app's lifetime; not part of the monitoring hot-swap teardown).
    private var appActiveObserver: NSObjectProtocol?

    // Pause / auto-resume
    private let ownBundleID = Bundle.main.bundleIdentifier
    private static let pauseModeKey = "pauseMode"
    /// Minutes the countdown resets to when a pause begins — a fresh normal
    /// interval (matches the engine's default working duration).
    private static let pauseResetMinutes = 20
    /// Wall-clock moment the user first left a `.currentApp` paused app.
    /// nil while they're in the app (or the grace timer hasn't started).
    /// Returning to the app clears it; exceeding the grace window resumes.
    private var currentAppAwaySince: Date?
    /// Grace period before a `.currentApp` pause auto-resumes after the user
    /// leaves the app — so brief tab/app switches mid-meeting don't resume
    /// Blink. Configurable in Settings (minutes); default 5, clamped ≥ 0.
    private var currentAppGraceSeconds: TimeInterval {
        let mins = (UserDefaults.standard.object(forKey: "currentAppGraceMinutes") as? Double) ?? 5
        return max(0, mins) * 60
    }

    // MARK: Calendar pause state

    private static let calendarActedKeysKey = "calendarActedKeys"
    /// Cap on the persisted acted-key ring so it can't grow unbounded. 50
    /// occurrences comfortably covers a day of back-to-back meetings; older
    /// keys roll off (harmless — those meetings are long over).
    private static let calendarActedKeysCap = 50
    /// Occurrence keys already handled (auto-paused or suggested), oldest
    /// first. Persisted so a meeting that ran past its scheduled end isn't
    /// re-paused after relaunch, and so an Undo isn't re-nagged. The Set is
    /// the lookup index for the array.
    private var calendarActedKeys: [String] = []
    private var calendarActedKeySet: Set<String> = []
    /// Whether link-less events get a suggestion toast. Mirrors the Settings
    /// default (on) at this non-view read site.
    private var suggestUnlinkedCalendarEvents: Bool {
        (UserDefaults.standard.object(forKey: "suggestUnlinkedEvents") as? Bool) ?? true
    }

    // MARK: - Computed

    var formattedRemaining: String {
        let mins = Int(remainingSeconds) / 60
        let secs = Int(remainingSeconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }

    /// True whenever a manual pause is active (any mode). Derived from
    /// `pauseMode` so the existing `isPaused` read sites (tick gate, menu
    /// bar icon opacity, popover labels) keep working untouched.
    var isPaused: Bool { pauseMode != nil }

    /// Human-readable pause status for the menu popover's state label.
    var pauseStatusText: String {
        switch pauseMode {
        case .none:
            return ""
        case .indefinite:
            return "Paused"
        case .timed(let until):
            return "Paused · resumes \(Self.resumeLabel(for: until))"
        case .currentApp(_, let name):
            return "Paused while \(name) is open"
        case .calendarEvent(_, _, let title):
            return "Paused for \(title)"
        }
    }

    /// Short "when it resumes" string: bare time if today, "tomorrow <time>"
    /// if tomorrow, else the time. Used only for display.
    private static func resumeLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        let time = formatter.string(from: date)
        let cal = Calendar.current
        if cal.isDateInToday(date) { return time }
        if cal.isDateInTomorrow(date) { return "tomorrow \(time)" }
        return time
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
    /// Driven by `com.apple.screenIsLocked` / `com.apple.screenIsUnlocked`
    /// on `DistributedNotificationCenter`, seeded once from
    /// `CGSSessionScreenIsLocked` at observer setup. Event-driven so the
    /// idle reset and wall-clock cap in BlinkEngine see "user is away"
    /// before the loginwindow → real-app switch on unlock bumps
    /// lastActivityTime and starves both safety nets.
    private var isScreenLocked = false

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

    /// True for SwiftUI-preview / snapshot-test instances. Lets views skip live
    /// system reads (e.g. TCC permission checks) so renders stay deterministic.
    let isPreview: Bool

    // MARK: - Init

    init(preview: Bool = false) {
        self.isPreview = preview
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
        restoreCalendarActedKeys()
        restorePauseMode()
        BlinkLog.pruneOldLogs()

        // Re-check permission-attention state whenever Blink regains focus —
        // catches the user granting/revoking a permission in System Settings
        // and switching back. Also refreshed once below after startup.
        appActiveObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshPermissionAlerts() }
        }
        refreshPermissionAlerts()

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
            if isUserAway {
                Log.i("Break due but user is away — suppressing (no overlay, no recording)")
                return
            }

            Log.i("Break #\(breakNumber) — showing overlay")
            isBreakPrompted = true
            overlayShownAt = Date()
            breaksPromptedToday += 1
            let suggestion = pickBreakSuggestion()
            overlayController.showBreak(
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
            overlayController.showFlowNudge(
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
            guard let self else { return }
            remainingSeconds = remaining
            timerTotal = total
        }

        engine.onStateChange = { [weak self] state in
            guard let self else { return }
            let prev = displayState
            if prev != state {
                Log.i("Engine state: \(prev) → \(state)")
            }
            displayState = state
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
            // Self-heal a mic grant stuck at .notDetermined for an ALREADY
            // set-up Smart-mode user. AVFoundation only syncs a microphone
            // grant made in System Settings once the app has called
            // requestAccess at least once — until then authorizationStatus
            // keeps returning .notDetermined even though the toggle is ON
            // (Apple DTS thread 738986). A major macOS upgrade migrates the
            // TCC database and re-exposes this: a previously-working grant now
            // reads .notDetermined, so MacContextDetector's `== .authorized`
            // gate silently kills meeting detection and breaks fire mid-call.
            // CRITICAL: only here (IM already granted) — NOT the permission-
            // flow branch below (a fresh install gets the dedicated mic page
            // at the right onboarding step) and NOT basic mode ("Zero
            // permissions", which returns above). Putting this at the top of
            // the method fired the prompt during the detection-mode page, and
            // even for Simple users — the bug this placement fixes.
            // requestAccess returns with NO prompt when the grant already
            // exists; gated on the call-detection setting so users who turned
            // it off see no mic UI.
            let micDetectionOn = (UserDefaults.standard.object(forKey: "pauseDuringCalls") as? Bool) ?? true
            let micSkipped = UserDefaults.standard.bool(forKey: "micOnboardingSkipped")
            if micStatus == .notDetermined && micDetectionOn && !micSkipped {
                Log.i("Existing Smart user with mic .notDetermined — requesting to sync grant")
                Task { @MainActor in
                    let micGranted = await PermissionManager.requestMicrophoneAccess()
                    Log.i("Mic re-request resolved → \(micGranted ? "authorized" : "denied")")
                }
            }
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
        maybeShowWhatsNew()
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
        stopCalendarMonitor()
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
        if let token = screenLockObserver {
            DistributedNotificationCenter.default().removeObserver(token)
            screenLockObserver = nil
        }
        if let token = screenUnlockObserver {
            DistributedNotificationCenter.default().removeObserver(token)
            screenUnlockObserver = nil
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
            guard let self else { return }
            self.engine.recordAppSwitch(bundleID: event.appBundleID)
            self.recordFrontmostApp(bundleID: event.appBundleID)
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
            recordFrontmostApp(bundleID: frontmostID)
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

        // Screen lock / unlock. NSWorkspace has no equivalent for plain
        // screen lock (Cmd+Ctrl+Q with display awake), so we listen on
        // DistributedNotificationCenter. On unlock we run the same path as
        // wake from sleep: a locked screen = user wasn't looking, treat as
        // eye rest, reset the timer state. Without this, the loginwindow →
        // real-app switch macOS fires on unlock bumps lastActivityTime,
        // which starves both BlinkEngine's stale-pending guard (step 1) and
        // its idle reset (step 4) — the wall-clock cap (step 5) then trips
        // on the first post-unlock tick and a phantom break fires.
        let dnc = DistributedNotificationCenter.default()
        // Seed once from the session dictionary in case we start up while
        // the screen is already locked (rare but possible).
        if let dict = CGSessionCopyCurrentDictionary() as? [String: Any],
           dict["CGSSessionScreenIsLocked"] as? Bool == true {
            isScreenLocked = true
        }
        screenLockObserver = dnc.addObserver(
            forName: NSNotification.Name("com.apple.screenIsLocked"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                Log.i("Screen locked")
                guard let self else { return }
                self.isScreenLocked = true
                if self.isBreakPrompted || self.overlayController.isShowingFullscreen {
                    Log.i("Break overlay active before lock — dismissing")
                    self.engine.userSkippedBreak()
                    self.isBreakPrompted = false
                    self.overlayController.dismissImmediately()
                }
            }
        }
        screenUnlockObserver = dnc.addObserver(
            forName: NSNotification.Name("com.apple.screenIsUnlocked"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                Log.i("Screen unlocked")
                guard let self else { return }
                self.isScreenLocked = false
                self.inputMonitor?.reEnableTapIfNeeded()
                if self.isBreakPrompted || self.overlayController.isShowingFullscreen {
                    Log.i("Break overlay still present on unlock — dismissing")
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

        // Start calendar watching if the user opted in previously (persisted
        // flag). Access may still be revoked — startCalendarMonitor re-checks.
        if UserDefaults.standard.bool(forKey: "pauseDuringCalendarEvents") {
            startCalendarMonitor()
        }

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

                // Periodically evaluate the calendar (auto-pause / suggest for
                // meetings). Throttled to every 30s; runs before checkAutoResume
                // so a pause taken this tick gates engine.tick() below.
                if self.calendarMonitor != nil {
                    self.ticksSinceCalendarCheck += 1
                    if self.ticksSinceCalendarCheck >= Self.calendarCheckTickInterval {
                        self.ticksSinceCalendarCheck = 0
                        self.evaluateCalendar()
                    }
                }

                // End any pause whose resume condition is now met (timer
                // elapsed, or the user switched away from the paused app)
                // before deciding whether to advance the engine this tick.
                self.checkAutoResume()

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

    /// Show the What's New window if this launch is the first on a new
    /// version. Deferred ~1.8s so it lands after the launch HUD's own
    /// settle — otherwise both windows compete for focus simultaneously.
    /// `WhatsNewManifest.itemsToShowOnLaunch()` owns the actual decision
    /// + bookkeeping; nil = don't show (brand-new install, same version,
    /// or empty manifest).
    private func maybeShowWhatsNew() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) { [weak self] in
            guard let self else { return }
            // itemsToShowOnLaunch() has a side effect (seeds lastSeenVersion),
            // so it must be called exactly once. nil → fresh install or nothing
            // new; fall through to the standalone calendar discoverability tip.
            guard let items = WhatsNewManifest.itemsToShowOnLaunch() else {
                self.maybeShowCalendarTip()
                return
            }
            // The upgrader is seeing the calendar card here — suppress the
            // separate tip so we don't double-announce.
            if items.contains(where: { $0.icon == "calendar" }) {
                UserDefaults.standard.set(true, forKey: Self.calendarTipShownKey)
            }
            let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
            // Record that this update surfaced What's New, so the Settings
            // "What's New" card can re-open the digest for the next 10 days.
            UserDefaults.standard.set(Date().timeIntervalSinceReferenceDate, forKey: Self.whatsNewSurfacedDateKey)
            UserDefaults.standard.set(version, forKey: Self.whatsNewSurfacedVersionKey)
            Log.i("Showing What's New window for v\(version) with \(items.count) item(s)")
            self.presentWhatsNew(version: version, items: items)
        }
    }

    static let whatsNewSurfacedDateKey = "whatsNewSurfacedDate"
    static let whatsNewSurfacedVersionKey = "whatsNewSurfacedVersion"
    /// How long the Settings "What's New" card stays visible after an update.
    static let whatsNewBadgeWindow: TimeInterval = 10 * 24 * 60 * 60

    /// Present the What's New window with the given items. Shared by the launch
    /// one-shot and the Settings "What's New" re-open card.
    func presentWhatsNew(version: String, items: [WhatsNewItem]) {
        guard !items.isEmpty else { return }
        whatsNewController = WhatsNewWindowController()
        whatsNewController?.show(
            theme: ThemeManager.shared.current,
            version: version,
            items: items,
            onOpenAction: { [weak self] action in
                switch action {
                case .preferences(let tab, let scrollTo):
                    self?.openPreferences(initialTab: tab, scrollTo: scrollTo)
                }
            }
        )
    }

    /// Re-open the current build's What's New digest from the Settings card.
    func showWhatsNewFromSettings() {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        presentWhatsNew(version: version, items: WhatsNewManifest.itemsForVersion(version))
    }

    /// The version to advertise in the Settings "What's New" card — non-nil
    /// only for `whatsNewBadgeWindow` (10 days) after an update surfaced the
    /// window, and only while the running build still matches. nil → no card.
    var recentlyUpdatedVersion: String? {
        let d = UserDefaults.standard
        guard let surfaced = d.string(forKey: Self.whatsNewSurfacedVersionKey) else { return nil }
        let current = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        guard surfaced == current else { return nil }
        let ts = d.double(forKey: Self.whatsNewSurfacedDateKey)
        guard ts > 0, Date().timeIntervalSinceReferenceDate - ts < Self.whatsNewBadgeWindow else { return nil }
        return WhatsNewManifest.itemsForVersion(current).isEmpty ? nil : current
    }

    private static let calendarTipShownKey = "calendarTipShown"

    /// One-time discoverability nudge for fresh users, who never see the
    /// What's New calendar card (What's New is suppressed on first install).
    /// Points them at Settings › Calendar with a scroll-to-highlight deep link.
    private func maybeShowCalendarTip() {
        guard !UserDefaults.standard.bool(forKey: Self.calendarTipShownKey) else { return }
        guard ThemeManager.shared.hasCompletedOnboarding else { return }
        // Already enabled → nothing to discover; mark shown and move on.
        if UserDefaults.standard.bool(forKey: "pauseDuringCalendarEvents") {
            UserDefaults.standard.set(true, forKey: Self.calendarTipShownKey)
            return
        }
        guard !isUserAway else { return }  // don't fire while asleep/locked
        UserDefaults.standard.set(true, forKey: Self.calendarTipShownKey)
        Log.i("Showing calendar discoverability tip")
        overlayController.showCalendarTip { [weak self] in
            self?.openPreferences(initialTab: 0, scrollTo: SettingsAnchor.calendar)
        }
    }

    /// Opens the Preferences window. Called from the launch HUD tap so
    /// the user has somewhere obvious to land if they can't find the menu
    /// bar icon. `initialTab` deep-links to a tab (0=General, 1=Theme,
    /// 2=Flow, 3=About) — honored only when the window isn't already open.
    func openPreferences(initialTab: Int = 0, scrollTo: String? = nil) {
        PreferencesWindowController.shared.show(appState: self, themeManager: ThemeManager.shared, initialTab: initialTab, scrollTo: scrollTo)
    }

    // MARK: - Public actions (for menu bar buttons)

    // MARK: - Pause / resume

    /// Enter a pause. Dismisses any live break overlay (pausing means "not
    /// now") and persists the mode so a timed pause survives relaunch.
    func pause(_ mode: PauseMode) {
        if isBreakPrompted || overlayController.isShowingFullscreen {
            Log.i("Pause requested while break overlay active — treating as skip")
            engine.userSkippedBreak()
            isBreakPrompted = false
            overlayShownAt = nil
            overlayController.dismissImmediately()
        }
        pauseMode = mode
        currentAppAwaySince = nil
        // A pause suspends the break functionality — it doesn't freeze the
        // timer mid-count. Reset to a fresh full interval so resuming (even
        // after an hour) starts a clean countdown instead of firing a break
        // seconds later. The tick gate holds it at full until resume.
        engine.userSnoozed(minutes: Self.pauseResetMinutes)
        persistPauseMode()
        Log.i("Paused → \(mode.logDescription)")
    }

    /// Leave the paused state. No-op if already running.
    func resume(reason: String = "user") {
        guard pauseMode != nil else { return }
        pauseMode = nil
        currentAppAwaySince = nil
        persistPauseMode()
        Log.i("Resumed (\(reason))")
    }

    /// Header button / legacy entry point: quick indefinite pause ⇄ resume.
    func togglePause() {
        if isPaused { resume(reason: "toggle") }
        else { pause(.indefinite) }
    }

    /// Runs every tick. Ends a pause whose resume condition is met.
    private func checkAutoResume() {
        guard let mode = pauseMode else { return }
        let now = Date()
        switch mode {
        case .indefinite:
            return

        case .timed(let until):
            guard now >= until else { return }
            autoResume(reason: "pause window elapsed", detail: "Your timed pause ended")

        case .calendarEvent(let until, _, _):
            guard now >= until else { return }
            // Scheduled end reached. If the mic is still hot the call is
            // likely running over — lift the pause (so the engine can act)
            // but SUPPRESS the "breaks are back" toast: the engine's own
            // mic-based meeting state will re-pause internally, so a resume
            // toast would be misleading. Its occurrence key stays acted, so
            // the calendar layer won't re-pause the same meeting.
            let micHot = contextDetector?.isMicrophoneActive() ?? false
            if micHot {
                resume(reason: "calendar meeting scheduled end (mic still active)")
            } else {
                autoResume(reason: "calendar meeting ended", detail: "Meeting ended")
            }

        case .currentApp(let bundleID, let name):
            // Filter out Blink itself so opening our own menu bar popover
            // (which can briefly make Blink frontmost) doesn't count as
            // "leaving" the paused app. Grace-timer decision is pure; the
            // away-since state lives here.
            let rawFront = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
            let front = (rawFront == ownBundleID) ? nil : rawFront
            let step = PauseMode.currentAppGraceStep(
                pausedBundleID: bundleID,
                frontmostBundleID: front,
                awaySince: currentAppAwaySince,
                now: now,
                graceSeconds: currentAppGraceSeconds
            )
            currentAppAwaySince = step.awaySince
            if step.resume {
                autoResume(reason: "away from \(name) past grace window",
                           detail: "You left \(name)")
            }
        }
    }

    /// Resume from an automatic trigger (timer elapsed / left the app) and
    /// surface a bottom-right toast so the user knows breaks are back on —
    /// they weren't the one who resumed. Suppressed while the user is away
    /// (asleep/locked), where a toast would be pointless.
    private func autoResume(reason: String, detail: String) {
        resume(reason: reason)
        if !isUserAway {
            overlayController.showResumeToast(detail: detail)
        }
    }

    /// Track the frontmost non-Blink app so the "pause while <App> is open"
    /// menu item always targets a real app.
    private func recordFrontmostApp(bundleID: String) {
        guard bundleID != ownBundleID else { return }
        lastActiveAppID = bundleID
        let running = NSWorkspace.shared.runningApplications.first { $0.bundleIdentifier == bundleID }
        lastActiveAppName = running?.localizedName ?? bundleID
    }

    // MARK: Pause persistence

    private func persistPauseMode() {
        let defaults = UserDefaults.standard
        if let mode = pauseMode, let data = try? JSONEncoder().encode(mode) {
            defaults.set(data, forKey: Self.pauseModeKey)
        } else {
            defaults.removeObject(forKey: Self.pauseModeKey)
        }
    }

    /// Restore a persisted pause at launch, dropping a `.timed` pause whose
    /// deadline already passed while Blink was quit. `.indefinite` and
    /// `.currentApp` restore as-is — the grace timer (re)starts from the tick
    /// loop, so a `.currentApp` pause survives a restart until the user is
    /// away from the app past the grace window.
    private func restorePauseMode() {
        guard let data = UserDefaults.standard.data(forKey: Self.pauseModeKey),
              let mode = try? JSONDecoder().decode(PauseMode.self, from: data) else { return }
        if mode.isElapsed(at: Date()) {
            Log.i("Discarding expired persisted pause (\(mode.logDescription))")
            UserDefaults.standard.removeObject(forKey: Self.pauseModeKey)
            return
        }
        pauseMode = mode
        // Seed a restored calendar pause's occurrence key so a meeting that
        // ran past its scheduled end isn't re-paused once this restored pause
        // elapses (the coordinator sees the key as already-acted).
        if case .calendarEvent(_, let key, _) = mode {
            markCalendarActed(key)
        }
        Log.i("Restored pause → \(mode.logDescription)")
    }

    // MARK: - Calendar integration

    /// Called from Settings when the "Pause during meetings" toggle changes.
    /// Enabling requests calendar access (and starts the monitor on grant);
    /// denial flips the toggle back and opens the Calendars settings pane.
    /// Disabling tears the monitor down.
    func setCalendarIntegration(enabled: Bool) {
        if enabled {
            Task { @MainActor in
                let granted = await PermissionManager.requestCalendarAccess()
                if granted {
                    self.startCalendarMonitor()
                } else {
                    Log.i("Calendar access denied — reverting toggle")
                    UserDefaults.standard.set(false, forKey: "pauseDuringCalendarEvents")
                    PermissionManager.openCalendarSettings()
                }
                self.refreshPermissionAlerts()
            }
        } else {
            stopCalendarMonitor()
            refreshPermissionAlerts()
        }
    }

    private func startCalendarMonitor() {
        guard calendarMonitor == nil else { return }
        guard PermissionManager.calendarAuthorizationStatus() == .fullAccess else {
            Log.i("Calendar monitor not started — access not granted")
            return
        }
        let monitor = MacCalendarMonitor()
        monitor.onStoreChanged = { [weak self] in
            // .EKEventStoreChanged posts on the main queue; hop into MainActor
            // isolation to touch @MainActor state (mirrors the sleep/wake obs).
            MainActor.assumeIsolated { self?.scheduleCalendarReevaluation() }
        }
        monitor.start()
        calendarMonitor = monitor
        ticksSinceCalendarCheck = 0
        Log.i("Calendar monitor started")
        evaluateCalendar()
    }

    private func stopCalendarMonitor() {
        calendarChangeDebounce?.cancel()
        calendarChangeDebounce = nil
        calendarMonitor?.stop()
        calendarMonitor = nil
    }

    /// Trailing-debounce a calendar re-evaluation after a store change.
    private func scheduleCalendarReevaluation() {
        calendarChangeDebounce?.cancel()
        let work = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated { self?.evaluateCalendar() }
        }
        calendarChangeDebounce = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: work)
    }

    /// Query the current meeting window and apply the coordinator's decision.
    private func evaluateCalendar() {
        guard let monitor = calendarMonitor, monitor.isAuthorized else { return }
        let now = Date()
        let meetings = monitor.meetings(now: now, ahead: Self.calendarLookAhead)
        let action = CalendarPauseCoordinator.decide(
            meetings: meetings,
            now: now,
            currentlyPaused: isPaused,
            actedKeys: calendarActedKeySet,
            suggestUnlinked: suggestUnlinkedCalendarEvents,
            suggestionLead: Self.calendarSuggestionLead
        )
        switch action {
        case .none:
            break
        case .autoPause(let meeting):
            applyCalendarAutoPause(meeting)
        case .suggest(let meeting):
            applyCalendarSuggestion(meeting)
        }
    }

    /// Auto-pause for a meeting with a video link, and show a dismissible
    /// "Paused for X · Undo" toast. Marked acted first so we never double-pause.
    private func applyCalendarAutoPause(_ meeting: CalendarMeeting) {
        markCalendarActed(meeting.occurrenceKey)
        pause(.calendarEvent(until: meeting.end, eventKey: meeting.occurrenceKey, title: meeting.title))
        guard !isUserAway else { return }
        let provider = meeting.link?.provider.displayName ?? "meeting"
        let detail = "\(provider) · until \(Self.resumeLabel(for: meeting.end))"
        overlayController.showMeetingPausedToast(title: meeting.title, detail: detail) { [weak self] in
            guard let self else { return }
            // Only undo if OUR calendar pause is still the active one — the
            // toast lingers ~15s, in which the user may have set a different
            // pause we must not blow away.
            if case .calendarEvent(_, let key, _) = self.pauseMode, key == meeting.occurrenceKey {
                self.resume(reason: "calendar undo")
            }
        }
    }

    /// Suggest a pause for a link-less meeting via an interactive toast. Marked
    /// acted (once actually shown) so we don't re-nag.
    private func applyCalendarSuggestion(_ meeting: CalendarMeeting) {
        // Don't consume the occurrence while the user can't see the toast —
        // mark acted only when we actually show it, so it surfaces on unlock.
        guard !isUserAway else { return }
        markCalendarActed(meeting.occurrenceKey)
        let minutes = max(1, Int(meeting.end.timeIntervalSince(Date()) / 60))
        overlayController.showMeetingSuggestionToast(title: meeting.title, minutes: minutes) { [weak self] in
            guard let self else { return }
            // Don't override a pause the user set after the toast appeared —
            // the never-override-a-manual-pause guard must hold for this
            // deferred action too, not just at decision time.
            guard !self.isPaused else { return }
            self.pause(.calendarEvent(until: meeting.end, eventKey: meeting.occurrenceKey, title: meeting.title))
        }
    }

    /// Record an occurrence as handled and persist the capped ring.
    private func markCalendarActed(_ key: String) {
        guard !calendarActedKeySet.contains(key) else { return }
        calendarActedKeys.append(key)
        if calendarActedKeys.count > Self.calendarActedKeysCap {
            let overflow = calendarActedKeys.count - Self.calendarActedKeysCap
            let dropped = calendarActedKeys.prefix(overflow)
            calendarActedKeys.removeFirst(overflow)
            dropped.forEach { calendarActedKeySet.remove($0) }
        }
        calendarActedKeySet.insert(key)
        UserDefaults.standard.set(calendarActedKeys, forKey: Self.calendarActedKeysKey)
    }

    private func restoreCalendarActedKeys() {
        let keys = UserDefaults.standard.stringArray(forKey: Self.calendarActedKeysKey) ?? []
        calendarActedKeys = keys
        calendarActedKeySet = Set(keys)
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
    ///
    /// Returns `.lookFarAway` unconditionally when the user has disabled
    /// the feature in Settings (`breakSuggestionsEnabled` defaults true).
    private func pickBreakSuggestion() -> BreakSuggestion {
        let enabled = (UserDefaults.standard.object(forKey: "breakSuggestionsEnabled") as? Bool) ?? true
        guard enabled else {
            Log.i("Break suggestion: disabled in Settings — defaulting to lookFarAway")
            lastBreakSuggestion = .lookFarAway
            return .lookFarAway
        }
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
