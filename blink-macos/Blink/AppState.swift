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
    @Published var hasAccessibilityPermission: Bool = false
    @Published var isVideoPlaying: Bool = false
    @Published var micAlwaysOnWarning: Bool = false
    @AppStorage("debugNotifications") var debugNotifications: Bool = false

    // Engine
    public let engine = BlinkEngine()

    // Platform monitors
    private var inputMonitor: MacInputMonitor?
    private var appMonitor: MacAppMonitor?
    private var contextDetector: MacContextDetector?
    private var permissionWindow: PermissionWindowController?

    // Timers
    private var tickTimer: Timer?

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

        setupEngineCallbacks()
        loadTodayStats()

        // Sync sensitivity from UserDefaults
        let saved = UserDefaults.standard.double(forKey: "flowSensitivity")
        if saved > 0 { engine.sensitivity = saved }

        let savedWallClock = UserDefaults.standard.integer(forKey: "maxWallClockMinutes")
        if savedWallClock > 0 { engine.maxWallClockSeconds = TimeInterval(savedWallClock * 60) }

        if ThemeManager.shared.hasCompletedOnboarding {
            checkPermissionsAndStart()
        } else {
            BlinkLog.app.info("Onboarding not complete — deferring permissions")
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
            self.isBreakPrompted = true
            self.breaksPromptedToday += 1
            self.overlayController.showBreak(
                breakNumber: breakNumber,
                onComplete: { [weak self] in
                    Task { @MainActor in
                        self?.engine.userTookBreak()
                        self?.isBreakPrompted = false
                        self?.breaksTakenToday += 1
                        self?.overlayController.dismiss()
                    }
                },
                onSkip: { [weak self] in
                    Task { @MainActor in
                        self?.engine.userSkippedBreak()
                        self?.isBreakPrompted = false
                        self?.overlayController.dismiss()
                    }
                }
            )
        }

        engine.onShowExtendToast = { [weak self] reason in
            guard let self else { return }
            BlinkLog.app.info("Break decision: extend — \(reason)")
            self.overlayController.showFlowNudge(
                message: "\(reason) — extended 10 min",
                // e.g. "Focused — extended 10 min"
                onTakeBreak: { [weak self] in
                    Task { @MainActor in
                        self?.engine.userTookBreak()
                        self?.isBreakPrompted = false
                    }
                }
            )
        }

        engine.onTimerUpdate = { [weak self] remaining, total in
            self?.remainingSeconds = remaining
            self?.timerTotal = total
        }

        engine.onStateChange = { [weak self] state in
            self?.displayState = state
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
        BlinkLog.app.info("Permission probe result: \(granted)")
        if granted {
            hasAccessibilityPermission = true
            UserDefaults.standard.set(true, forKey: "permissionGranted")
            startMonitoring()
            startTimer()
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
                self.startTimer()
                self.showTimerForStartup()
                BlinkLog.app.info("Permission granted — monitors and timers started")
            }
        }
    }

    private func startMonitoring() {
        BlinkLog.app.info("Starting input monitoring (CGEventTap)")
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

        BlinkLog.app.info("Starting app monitor (NSWorkspace)")
        let appMon = MacAppMonitor()
        appMon.onAppSwitch = { [weak self] event in
            BlinkLog.app.debug("App switch → \(event.appBundleID)")
            self?.engine.recordAppSwitch(bundleID: event.appBundleID)
        }
        appMon.onWindowTitleChange = {
            BlinkLog.app.debug("Window title changed")
        }
        appMon.startMonitoring()
        self.appMonitor = appMon

        // Re-enable CGEventTap after Mac wakes from sleep
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            BlinkLog.app.info("Wake from sleep")
            self?.inputMonitor?.reEnableTapIfNeeded()
            // If break overlay was showing before sleep, dismiss it — user was away
            if self?.isBreakPrompted == true {
                BlinkLog.app.info("Break overlay was showing before sleep — dismissing")
                self?.engine.userTookBreak()
                self?.isBreakPrompted = false
                self?.overlayController.dismiss()
            }
            self?.engine.wakeFromSleep()
        }

        let ctx = MacContextDetector()
        ctx.onMicActiveAtLaunch = { [weak self] in
            DispatchQueue.main.async { self?.micAlwaysOnWarning = true }
        }
        self.contextDetector = ctx
        BlinkLog.app.info("All monitors active")

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

                // Tap health check + fallback polling
                self.inputMonitor?.reEnableTapIfNeeded()
                if self.inputMonitor?.isTapAlive != true {
                    self.pollInputFallback()
                }

                self.engine.tick()
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

    // MARK: - Public actions (for menu bar buttons)

    func showBreakPrompt() {
        engine.onShowBreak?(engine.currentBreakStreak + 1)
    }

    // MARK: - Persistence

    private func loadTodayStats() {
        let records = persistence.loadTodayRecords()
        breaksPromptedToday = records.count
        breaksTakenToday = records.filter { $0.compliance == .taken || $0.compliance == .delayed }.count
        BlinkLog.app.info("Loaded today's stats: \(self.breaksTakenToday)/\(self.breaksPromptedToday) breaks taken")
    }
}
