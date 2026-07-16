import SwiftUI
import AppKit
import BlinkCore

/// Manages the break overlay flow:
/// 1. Mini toast in bottom-right (3s heads-up)
/// 2. Fullscreen countdown (3s)
/// 3. Break timer (20s)
final class OverlayWindowController {
    private var toastWindow: NSWindow?
    private var fullscreenWindow: NSWindow?
    private var keyMonitor: Any?
    private var globalKeyMonitor: Any?
    private var clickMonitor: Any?
    private var isDismissing = false

    /// The app that was frontmost just before the break overlay stole focus.
    /// Captured in `showBreakTimer`, re-activated on dismiss so the user lands
    /// back in whatever they were doing instead of in Blink.
    private var previousFrontmostApp: NSRunningApplication?

    /// True when the fullscreen break overlay window exists and is visible.
    var isShowingFullscreen: Bool { fullscreenWindow != nil }

    private var theme: BlinkTheme {
        UserDefaults.standard.bool(forKey: "useDarkOverlay")
        ? .dark
        : ThemeManager.shared.current
    }
    
    func showBreak(breakNumber: Int = 0,
                   suggestion: BreakSuggestion = .lookFarAway,
                   skipToast: Bool = false,
                   onComplete: @escaping () -> Void,
                   onSkip: @escaping () -> Void) {
        if skipToast {
            // Manual trigger — go directly to break timer without toast
            Log.i("Break overlay: skipping toast, showing fullscreen directly (break #\(breakNumber), suggestion=\(suggestion.rawValue))")
            showBreakTimer(breakNumber: breakNumber, suggestion: suggestion, onComplete: onComplete, onSkip: onSkip)
        } else {
            // Automatic trigger — show toast first
            Log.i("Break overlay: showing 3s toast before fullscreen (break #\(breakNumber), suggestion=\(suggestion.rawValue))")
            showToast(onToastDone: { [weak self] in
                self?.dismissToast()
                self?.showBreakTimer(breakNumber: breakNumber, suggestion: suggestion, onComplete: onComplete, onSkip: onSkip)
            })
        }
    }
    
    /// Show a "timer extended" toast when flow is detected.
    /// User can dismiss (keep extension) or tap "Take break now".
    func showTimerExtendedToast(onTakeBreakNow: @escaping () -> Void) {
        Log.i("Timer extended toast: showing flow-detected nudge")
        // Don't stack on existing toast
        dismissToast()
        
        guard let screen = NSScreen.main else { return }
        
        let toastWidth: CGFloat = 280
        let toastHeight: CGFloat = 72
        let padding: CGFloat = 16
        
        let toastFrame = NSRect(
            x: screen.visibleFrame.maxX - toastWidth - padding,
            y: screen.visibleFrame.minY + padding,
            width: toastWidth,
            height: toastHeight
        )
        
        let toastView = TimerExtendedToastView(
            theme: theme,
            onDismiss: { [weak self] in
                Log.i("Timer extended toast: dismissed by user")
                self?.dismissToast()
            },
            onTakeBreak: { [weak self] in
                Log.i("Timer extended toast: 'Take break now' tapped")
                self?.dismissToast()
                onTakeBreakNow()
            }
        )
        
        let panel = NSPanel(
            contentRect: toastFrame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.ignoresMouseEvents = false  // clickable
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary]
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = true
        
        panel.contentView = NSHostingView(rootView: toastView)
        
        let win = panel
        win.alphaValue = 0
        win.orderFrontRegardless()
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            win.animator().alphaValue = 1
        }
        
        self.toastWindow = win
        
        // Auto-dismiss after 7 seconds if not interacted with
        DispatchQueue.main.asyncAfter(deadline: .now() + 7) { [weak self] in
            self?.dismissToast()
        }
    }
    
    /// Show a welcome toast near the menu bar after permission is granted.
    func showMenuBarWelcome() {
        dismissToast()

        guard let screen = NSScreen.main else { return }

        let toastWidth: CGFloat = 300
        let toastHeight: CGFloat = 56
        let padding: CGFloat = 16

        // Position top-right, near the menu bar
        let toastFrame = NSRect(
            x: screen.visibleFrame.maxX - toastWidth - padding,
            y: screen.visibleFrame.maxY - toastHeight - padding,
            width: toastWidth,
            height: toastHeight
        )

        let bg = theme.overlayBackground(for: NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? .dark : .light)
        let fg = theme.overlayText(for: NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? .dark : .light)

        let view = HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 20))
                .foregroundStyle(.green)
            VStack(alignment: .leading, spacing: 2) {
                Text("Blink is running!")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(fg)
                Text("Click the icon in your menu bar ↑")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(fg)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(bg)
        .clipShape(RoundedRectangle(cornerRadius: 12))

        let panel = NSPanel(
            contentRect: toastFrame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary]
        panel.hidesOnDeactivate = false
        panel.contentView = NSHostingView(rootView: AnyView(view))

        panel.alphaValue = 0
        panel.orderFrontRegardless()

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.3
            panel.animator().alphaValue = 1
        }

        self.toastWindow = panel

        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            self?.dismissToast()
        }
    }

    /// Show a gentle nudge during flow — non-intrusive toast that auto-dismisses after 7s.
    func showFlowNudge(message: String, onTakeBreak: @escaping () -> Void) {
        Log.i("Flow nudge toast: \(message)")
        dismissToast()

        guard let screen = NSScreen.main else { return }

        let toastWidth: CGFloat = 320
        let toastHeight: CGFloat = 80
        let padding: CGFloat = 16

        let toastFrame = NSRect(
            x: screen.visibleFrame.maxX - toastWidth - padding,
            y: screen.visibleFrame.minY + padding,
            width: toastWidth,
            height: toastHeight
        )

        let toastView = FlowNudgeToastView(
            theme: theme,
            message: message,
            onDismiss: { [weak self] in
                Log.i("Flow nudge toast: dismissed by user")
                self?.dismissToast()
            },
            onTakeBreak: { [weak self] in
                Log.i("Flow nudge toast: 'Take break' tapped")
                self?.dismissToast()
                onTakeBreak()
            }
        )

        let panel = NSPanel(
            contentRect: toastFrame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.ignoresMouseEvents = false
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary]
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = true

        panel.contentView = NSHostingView(rootView: toastView)

        panel.alphaValue = 0
        panel.orderFrontRegardless()

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            panel.animator().alphaValue = 1
        }

        self.toastWindow = panel

        DispatchQueue.main.asyncAfter(deadline: .now() + 7) { [weak self] in
            self?.dismissToast()
        }
    }

    func showDebugToast(_ message: String) {
        dismissToast()
        
        guard let screen = NSScreen.main else { return }
        
        let toastWidth: CGFloat = 320
        let toastHeight: CGFloat = 44
        let padding: CGFloat = 16
        
        let toastFrame = NSRect(
            x: screen.visibleFrame.maxX - toastWidth - padding,
            y: screen.visibleFrame.minY + padding,
            width: toastWidth,
            height: toastHeight
        )
        
        let view = DebugToastView(message: message)
        
        let panel = NSPanel(
            contentRect: toastFrame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary]
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.contentView = NSHostingView(rootView: view)
        
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.2
            panel.animator().alphaValue = 1
        }
        
        self.toastWindow = panel

        DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [weak self] in
            self?.dismissToast()
        }
    }

    /// Bottom-right toast confirming Blink auto-resumed (timed pause elapsed or
    /// the user left a paused app). Non-interactive, auto-dismisses after 5s —
    /// mirrors the flow-nudge toast styling.
    func showResumeToast(detail: String) {
        Log.i("Resume toast: \(detail)")
        dismissToast()

        guard let screen = NSScreen.main else { return }

        let toastWidth: CGFloat = 320
        let toastHeight: CGFloat = 72
        let padding: CGFloat = 16

        let toastFrame = NSRect(
            x: screen.visibleFrame.maxX - toastWidth - padding,
            y: screen.visibleFrame.minY + padding,
            width: toastWidth,
            height: toastHeight
        )

        let toastView = ResumeToastView(theme: theme, detail: detail)

        let panel = NSPanel(
            contentRect: toastFrame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary]
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.contentView = NSHostingView(rootView: toastView)

        panel.alphaValue = 0
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.3
            panel.animator().alphaValue = 1
        }

        self.toastWindow = panel

        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            self?.dismissToast()
        }
    }

    /// Interactive bottom-right toast shown when Blink auto-pauses for a
    /// calendar meeting with a video link. Tapping "Undo" resumes immediately.
    func showMeetingPausedToast(title: String, detail: String, onUndo: @escaping () -> Void) {
        Log.i("Meeting paused toast: \(title) — \(detail)")
        let view = MeetingActionToastView(
            theme: theme,
            icon: "calendar",
            title: "Paused for \(title)",
            detail: detail,
            actionLabel: "Undo",
            onAction: { [weak self] in
                Log.i("Meeting paused toast: 'Undo' tapped")
                self?.dismissToast()
                onUndo()
            }
        )
        installInteractiveToast(view, width: 320, height: 72, autoDismiss: 15)
    }

    /// Interactive bottom-right toast suggesting a pause for a calendar event
    /// that has NO video link. Tapping "Pause" pauses for the event's duration.
    func showMeetingSuggestionToast(title: String, minutes: Int, onPause: @escaping () -> Void) {
        Log.i("Meeting suggestion toast: \(title) (\(minutes)m)")
        let view = MeetingActionToastView(
            theme: theme,
            icon: "calendar.badge.clock",
            title: "\(title) starting",
            detail: "Pause Blink for \(minutes)m?",
            actionLabel: "Pause",
            onAction: { [weak self] in
                Log.i("Meeting suggestion toast: 'Pause' tapped")
                self?.dismissToast()
                onPause()
            }
        )
        installInteractiveToast(view, width: 320, height: 72, autoDismiss: 15)
    }

    /// One-time discoverability tip pointing fresh users at the calendar
    /// auto-pause setting. Tapping "Open" deep-links into Settings › Calendar.
    func showCalendarTip(onOpen: @escaping () -> Void) {
        Log.i("Calendar discoverability tip shown")
        let view = MeetingActionToastView(
            theme: theme,
            icon: "calendar",
            title: "Auto-pause during meetings",
            detail: "Turn it on in Settings › Calendar",
            actionLabel: "Open",
            onAction: { [weak self] in
                Log.i("Calendar tip: 'Open' tapped")
                self?.dismissToast()
                onOpen()
            }
        )
        installInteractiveToast(view, width: 340, height: 72, autoDismiss: 12)
    }

    /// Shared setup for an interactive (clickable) bottom-right toast. Mirrors
    /// the `TimerExtendedToastView` / `FlowNudgeToastView` panel config:
    /// `.nonactivatingPanel` + `becomesKeyOnlyIfNeeded` so the button receives
    /// clicks without stealing focus from the LSUIElement app.
    private func installInteractiveToast<Content: View>(
        _ content: Content,
        width: CGFloat,
        height: CGFloat,
        autoDismiss: TimeInterval
    ) {
        dismissToast()
        guard let screen = NSScreen.main else { return }

        let padding: CGFloat = 16
        let frame = NSRect(
            x: screen.visibleFrame.maxX - width - padding,
            y: screen.visibleFrame.minY + padding,
            width: width,
            height: height
        )

        let panel = NSPanel(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.ignoresMouseEvents = false
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary]
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.contentView = NSHostingView(rootView: content)

        panel.alphaValue = 0
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.3
            panel.animator().alphaValue = 1
        }
        self.toastWindow = panel

        if autoDismiss > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + autoDismiss) { [weak self] in
                self?.dismissToast()
            }
        }
    }

    // MARK: - Phase 1: Mini toast (bottom-right corner)

    private func showToast(onToastDone: @escaping () -> Void) {
        guard let screen = NSScreen.main else { return }
        
        let toastWidth: CGFloat = 280
        let toastHeight: CGFloat = 72
        let padding: CGFloat = 16
        
        let toastFrame = NSRect(
            x: screen.visibleFrame.maxX - toastWidth - padding,
            y: screen.visibleFrame.minY + padding,
            width: toastWidth,
            height: toastHeight
        )
        
        let toastView = ToastView(theme: theme, onDone: { onToastDone() })
        
        let panel = NSPanel(
            contentRect: toastFrame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary]
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = true
        
        panel.contentView = NSHostingView(rootView: toastView)
        
        let win = panel
        win.alphaValue = 0
        win.orderFrontRegardless()
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            win.animator().alphaValue = 1
        }
        
        self.toastWindow = win
    }
    
    private func dismissToast() {
        guard let win = toastWindow else { return }
        toastWindow = nil
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            win.animator().alphaValue = 0
        }, completionHandler: {
            win.orderOut(nil)
        })
    }
    
    // MARK: - Fullscreen break timer
    
    private func showBreakTimer(breakNumber: Int = 0,
                                suggestion: BreakSuggestion = .lookFarAway,
                                onComplete: @escaping () -> Void,
                                onSkip: @escaping () -> Void) {
        Log.i("Fullscreen break overlay: creating window (break #\(breakNumber), suggestion=\(suggestion.rawValue))")
        guard let screen = NSScreen.main else { return }

        // Borderless overlay at .screenSaver level — covers everything instantly.
        // Close button always visible. isUserAway gate prevents showing during sleep/lock.
        let win = NSWindow(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        win.level = .screenSaver
        win.isOpaque = false
        win.backgroundColor = .clear
        win.ignoresMouseEvents = false
        win.collectionBehavior = [.fullScreenAuxiliary]
        win.alphaValue = 0

        // Reposition if screen geometry changes (lid close/open, display switch)
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil, queue: .main
        ) { [weak win] _ in
            if let screen = NSScreen.main, let win {
                win.setFrame(screen.frame, display: true)
            }
        }

        self.fullscreenWindow = win
        isDismissing = false

        let skipAction = { [weak self] in
            self?.dismissFullscreen()
            onSkip()
        }

        // Default eye-rest keeps the canonical 20-20-20 second window.
        // The five enriched suggestions (with icon + subtitle copy) get
        // 25s so the user actually has time to read the prompt.
        let breakDuration = (suggestion == .lookFarAway) ? 20 : 25
        Log.i("Break overlay: countdown duration = \(breakDuration)s (suggestion=\(suggestion.rawValue))")
        let breakModel = BreakPhaseModel(duration: breakDuration)
        let breakView = BreakPhaseView(
            theme: theme,
            model: breakModel,
            suggestion: suggestion,
            onDismiss: { [weak self] in
                // Kill-switch: try normal dismiss, then nuke if still alive
                Log.i("Break overlay: X button (kill-switch) tapped")
                skipAction()
                DispatchQueue.main.async {
                    self?.dismissImmediately()
                }
            },
            onComplete: { [weak self] in
                self?.dismissFullscreen()
                onComplete()
            },
            onSkip: skipAction
        )

        // Keyboard handling — local (app active) + global (app in background)
        removeEventMonitors()
        currentKeyHandler = KeyEventHandler(
            onEscape: {
                Log.i("Break overlay: Escape key pressed — skipping break")
                skipAction()
            },
            onRightArrow: { [weak breakModel] in
                Log.i("Break overlay: right arrow pressed — extending break +20s")
                breakModel?.extend()
            }
        )
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if self?.currentKeyHandler?.handle(event) == true {
                return nil
            }
            return event
        }
        globalKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            _ = self?.currentKeyHandler?.handle(event)
        }
        // Click anywhere after countdown reaches 0 → skip break
        clickMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak breakModel] event in
            if breakModel?.remaining ?? 1 <= 0 {
                Log.i("Break overlay: click-to-dismiss after countdown reached 0")
                skipAction()
                return nil
            }
            return event
        }

        win.contentView = NSHostingView(rootView: AnyView(breakView))

        // Remember who was frontmost so we can hand focus back when the break
        // ends. Skip Blink itself (and any non-regular app) — restoring to our
        // own menu-bar app would just leave the user staring at nothing.
        let frontmost = NSWorkspace.shared.frontmostApplication
        if let frontmost, frontmost.bundleIdentifier != Bundle.main.bundleIdentifier {
            previousFrontmostApp = frontmost
            Log.i("Break overlay: captured frontmost app for restore: \(frontmost.bundleIdentifier ?? "?")")
        } else {
            previousFrontmostApp = nil
        }

        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            win.animator().alphaValue = 1
        }
    }
    
    private var currentKeyHandler: KeyEventHandler?
    
    private func removeEventMonitors() {
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
        if let monitor = globalKeyMonitor {
            NSEvent.removeMonitor(monitor)
            globalKeyMonitor = nil
        }
        if let monitor = clickMonitor {
            NSEvent.removeMonitor(monitor)
            clickMonitor = nil
        }
        currentKeyHandler = nil
    }
    
    /// Hand keyboard focus back to whatever app was frontmost before the break
    /// stole it. No-op if we never captured one (e.g. Blink was frontmost).
    private func restorePreviousApp() {
        guard let app = previousFrontmostApp else { return }
        previousFrontmostApp = nil
        guard !app.isTerminated else { return }
        Log.i("Break overlay: restoring focus to \(app.bundleIdentifier ?? "?")")
        app.activate(options: [])
    }

    private func dismissFullscreen() {
        guard !isDismissing else { return }
        isDismissing = true
        Log.i("Fullscreen overlay: dismissing (fade-out)")
        removeEventMonitors()
        guard let win = fullscreenWindow else { return }
        fullscreenWindow = nil
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.3
            win.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            win.orderOut(nil)
            self?.restorePreviousApp()
        })
    }

    func dismiss() {
        dismissToast()
        dismissFullscreen()
    }

    /// Synchronous dismiss with no animation — for willSleep / wake where
    /// we can't afford to wait for a 0.3s fade that may never complete.
    func dismissImmediately() {
        guard !isDismissing else { return }
        isDismissing = true
        Log.i("Fullscreen overlay: dismissing immediately (no animation)")
        dismissToast()
        removeEventMonitors()
        guard let win = fullscreenWindow else { return }
        fullscreenWindow = nil
        win.alphaValue = 0
        win.orderOut(nil)
        restorePreviousApp()
    }
}

// MARK: - Toast (bottom-right heads-up)

struct ToastView: View {
    let theme: BlinkTheme
    let onDone: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    @State private var count: Int = 3
    @State private var timer: Timer?

    var body: some View {
        let bg = theme.overlayBackground(for: colorScheme)
        let fg = theme.overlayText(for: colorScheme)
        let accent = theme.accent(for: colorScheme)
        HStack(spacing: 12) {
            Image(systemName: "eye")
                .font(.system(size: 20))
                .foregroundStyle(fg)

            VStack(alignment: .leading, spacing: 2) {
                Text("Break in \(count)s")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(fg)
            }

            Spacer()

            ZStack {
                Circle()
                    .stroke(accent.opacity(0.3), lineWidth: 2)
                    .frame(width: 28, height: 28)
                Circle()
                    .trim(from: 0, to: CGFloat(count) / 3.0)
                    .stroke(accent, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .frame(width: 28, height: 28)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: count)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(bg)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .onAppear { startTimer() }
        .onDisappear { stopTimer() }
    }
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if count > 1 { count -= 1 } else { stopTimer(); onDone() }
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}

// MARK: - Timer extended toast

struct TimerExtendedToastView: View {
    let theme: BlinkTheme
    let onDismiss: () -> Void
    let onTakeBreak: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let bg = theme.overlayBackground(for: colorScheme)
        let fg = theme.overlayText(for: colorScheme)
        let accent = theme.accent(for: colorScheme)
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 14))
                    .foregroundStyle(fg)

                Text("In flow — timer extended")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(fg)
            }

            Button {
                onTakeBreak()
            } label: {
                Text("Take break now")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(theme.textOnAccent(for: colorScheme))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 5)
                    .background(accent)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(bg)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Key event handler (NSEvent-based, works in borderless windows)

private final class KeyEventHandler {
    let onEscape: (() -> Void)?
    let onRightArrow: (() -> Void)?
    
    init(onEscape: (() -> Void)? = nil, onRightArrow: (() -> Void)? = nil) {
        self.onEscape = onEscape
        self.onRightArrow = onRightArrow
    }
    
    /// Returns true if the event was consumed.
    func handle(_ event: NSEvent) -> Bool {
        switch event.keyCode {
        case 53: // Escape
            onEscape?()
            return true
        case 124: // Right arrow
            if let action = onRightArrow {
                action()
                return true
            }
            return false
        default:
            return false
        }
    }
}

// MARK: - Fullscreen countdown (3... 2... 1...)

struct CountdownPhaseView: View {
    let theme: BlinkTheme
    let onCountdownDone: () -> Void
    let onSkip: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var count: Int = 3
    @State private var timer: Timer?
    @State private var scale: CGFloat = 1.0
    
    var body: some View {
        let bg = theme.overlayBackground(for: colorScheme)
        let fg = theme.overlayText(for: colorScheme)
        ZStack {
            bg.ignoresSafeArea()
            
            VStack(spacing: 20) {
                Text("Break starting in")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(fg)
                
                Text("\(count)")
                    .font(.system(size: 96, weight: .ultraLight, design: .rounded))
                    .foregroundStyle(theme.accent(for: colorScheme))
                    .scaleEffect(scale)
                    .animation(.easeOut(duration: 0.3), value: count)
                
                Text("esc to skip")
                    .font(.system(size: 13))
                    .foregroundStyle(fg)
                    .padding(.top, 16)
            }
        }
        .onAppear { startTimer() }
        .onDisappear { stopTimer() }
    }
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if count > 1 {
                count -= 1
                scale = 1.2
                withAnimation(.easeOut(duration: 0.3)) { scale = 1.0 }
            } else {
                stopTimer(); onCountdownDone()
            }
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}

// MARK: - Break phase model (shared with key handler)

final class BreakPhaseModel: ObservableObject {
    @Published var remaining: Int
    @Published var total: Int
    @Published var showExtendHint: Bool = false
    var timer: Timer?

    /// Wall-clock timestamp when the countdown started (for surviving sleep).
    private var countdownStartDate: Date?
    /// Total seconds that were on the clock at start (adjusted for extends).
    private var countdownStartTotal: Int

    /// `duration` defaults to the 20-20-20 rule's 20s. Caller may pass a
    /// longer duration (e.g. 25s) when the break overlay shows a
    /// suggestion subtitle the user needs time to read.
    init(duration: Int = 20) {
        self.remaining = duration
        self.total = duration
        self.countdownStartTotal = duration
    }

    deinit {
        stopTimer()
    }

    func extend() {
        remaining += 20
        total += 20
        // Adjust wall-clock baseline so elapsed calculation stays correct
        countdownStartTotal += 20
        Log.i("BreakPhaseModel: extended +20s → total=\(total)s, remaining=\(remaining)s")
        withAnimation(.easeOut(duration: 0.4)) { showExtendHint = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            withAnimation { self?.showExtendHint = false }
        }
    }

    func startTimer(onComplete: @escaping () -> Void) {
        Log.i("BreakPhaseModel: countdown started (\(total)s)")
        countdownStartDate = Date()
        countdownStartTotal = total
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self, let startDate = self.countdownStartDate else { return }

            // Use wall-clock elapsed time so sleep doesn't freeze the countdown
            let elapsed = Date().timeIntervalSince(startDate)
            let wallRemaining = self.countdownStartTotal - Int(elapsed)

            if wallRemaining > 0 {
                self.remaining = wallRemaining
            } else {
                // Countdown done — dismiss immediately
                Log.i("BreakPhaseModel: countdown reached 0 — auto-completing break")
                self.remaining = 0
                self.stopTimer()
                onComplete()
            }
        }
    }

    func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}

// MARK: - Break timer (20s)

struct BreakPhaseView: View {
    let theme: BlinkTheme
    @ObservedObject var model: BreakPhaseModel
    var suggestion: BreakSuggestion = .lookFarAway
    var onDismiss: (() -> Void)?
    let onComplete: () -> Void
    let onSkip: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    // Drives the entrance animation. Defaults false; flipped true in
    // .onAppear. Crucially, only `scaleEffect` and SF Symbol bounce are
    // gated on this — opacity stays at 1 at rest so synchronous renders
    // (ImageRenderer / snapshot tests) capture a fully-visible header
    // even when .onAppear's DispatchQueue.main.async never runs.
    @State private var headerEntered: Bool = false

    // Drives the slow attention pulse on the suggestion title (non-
    // .lookFarAway only). Defaults false → rest scale is 1.0, so snapshot
    // tests still capture the title at its natural size. After the
    // entrance settles we flip it true and the title gently breathes
    // between 1.0 and 1.035 in an autoreversed easeInOut loop so the
    // user's eye lands on the call-to-action.
    @State private var titlePulse: Bool = false

    var body: some View {
        let fg = theme.onBackgroundText(for: colorScheme)
        ZStack {
            theme.backgroundGradient(for: colorScheme)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Suggestion header — icon, title, short subtitle.
                // Replaces the old fixed "Look at something far away" copy;
                // the actual suggestion is chosen by BreakSuggestionPicker
                // from flow + sedentary + time-of-day + recent compliance.
                HStack {
                    Spacer()
                    VStack(spacing: 10) {
                        // The default eye-rest suggestion keeps the
                        // original minimal design: title only, no icon
                        // or subtitle. The other 5 suggestions get the
                        // full icon + title + subtitle treatment because
                        // they're calls-to-action (drink, walk, breathe…)
                        // where the icon adds quick visual semantics.
                        if suggestion != .lookFarAway {
                            Image(systemName: suggestion.iconName)
                                .font(.system(size: 32, weight: .light))
                                .foregroundStyle(fg)
                                .symbolRenderingMode(.hierarchical)
                                .symbolEffect(.bounce, options: .nonRepeating, value: headerEntered)
                        }

                        Text(suggestion.title)
                            .font(.system(size: 24, weight: .medium))
                            .foregroundStyle(fg)
                            .multilineTextAlignment(.center)
                            .scaleEffect(titlePulse ? 1.035 : 1.0)
                            .animation(
                                .easeInOut(duration: 1.3).repeatForever(autoreverses: true),
                                value: titlePulse
                            )

                        if suggestion != .lookFarAway {
                            Text(suggestion.subtitle)
                                .font(.system(size: 13))
                                .foregroundStyle(fg.opacity(0.75))
                                .multilineTextAlignment(.center)
                        }
                    }
                    // scaleEffect is the only entrance-gated property —
                    // a 0.96 → 1.0 spring on appear. At rest (snapshot
                    // pass) the header renders at 0.96× scale, fully
                    // visible. Opacity is never touched.
                    .scaleEffect(headerEntered ? 1.0 : 0.96)
                    .animation(.spring(duration: 0.55, bounce: 0.25), value: headerEntered)
                    Spacer()
                }
                .padding(.top, 80)
                
                Spacer()
                
                // Timer
                ZStack {
                    let accentColor = theme.accent(for: colorScheme)
                    Circle()
                        .stroke(accentColor.opacity(0.15), lineWidth: 5)
                        .frame(width: 220, height: 220)

                    Circle()
                        .trim(from: 0, to: CGFloat(model.remaining) / CGFloat(model.total))
                        .stroke(accentColor, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                        .frame(width: 220, height: 220)
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 1), value: model.remaining)

                    Text("\(model.remaining)")
                        .font(.system(size: 80, weight: .ultraLight, design: .monospaced))
                        .foregroundStyle(fg)
                }
                
                Text("+20s")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(fg)
                    .opacity(model.showExtendHint ? 1 : 0)
                    .animation(.easeInOut(duration: 0.3), value: model.showExtendHint)
                    .padding(.top, 10)
                
                Spacer()
                
                Button {
                    onSkip()
                    GaborExerciseWindowController.shared.show(theme: theme)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "eye.circle")
                            .font(.system(size: 16))
                        Text("Train Eyes")
                            .font(.system(size: 16, weight: .medium))
                    }
                    .foregroundStyle(fg)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(fg.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(fg.opacity(0.2), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .padding(.bottom, 40)
                
                
                HStack(spacing: 32) {
                    KeyHintView(key: "esc", label: "Skip break", theme: theme)
                    KeyHintView(key: "→", label: "Extend 20s", theme: theme)
                }
                
                Spacer()
                    .frame(height: 20)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea()
        }
        .onAppear {
            model.startTimer(onComplete: onComplete)
            // Trigger the scale-spring + icon bounce a beat after the
            // window's own NSAnimationContext fade-in starts.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                headerEntered = true
            }
            // Start the title-pulse after the entrance spring settles, and
            // only for real suggestions — the default "Look at something
            // far away" deliberately stays still (it doesn't need a
            // call-to-action nudge).
            if suggestion != .lookFarAway {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    titlePulse = true
                }
            }
        }
        .onDisappear { model.stopTimer() }
    }
}

// MARK: - Key hint component

struct KeyHintView: View {
    let key: String
    let label: String
    let theme: BlinkTheme
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        let fg = theme.onBackgroundText(for: colorScheme)
        HStack(spacing: 10) {
            Text(key)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(fg)
                .frame(minWidth: 36, minHeight: 28)
                .padding(.horizontal, 8)
                .background(fg.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(fg.opacity(0.2), lineWidth: 1)
                )
            
            Text(label)
                .font(.system(size: 15))
                .foregroundStyle(fg)
        }
    }
}

// MARK: - Debug toast

// MARK: - Flow nudge toast

struct FlowNudgeToastView: View {
    let theme: BlinkTheme
    let message: String
    let onDismiss: () -> Void
    let onTakeBreak: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let bg = theme.overlayBackground(for: colorScheme)
        let fg = theme.overlayText(for: colorScheme)
        let accent = theme.accent(for: colorScheme)

        HStack(spacing: 12) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 20))
                .foregroundStyle(fg)

            VStack(alignment: .leading, spacing: 2) {
                Text(message)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(fg)
                    .lineLimit(2)
            }

            Spacer()

            Button {
                onTakeBreak()
            } label: {
                Text("Break")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(theme.textOnAccent(for: colorScheme))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(accent)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(bg)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct ResumeToastView: View {
    let theme: BlinkTheme
    let detail: String
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let bg = theme.overlayBackground(for: colorScheme)
        let fg = theme.overlayText(for: colorScheme)
        let accent = theme.accent(for: colorScheme)

        HStack(spacing: 12) {
            Image(systemName: "eye")
                .font(.system(size: 20))
                .foregroundStyle(accent)

            VStack(alignment: .leading, spacing: 2) {
                Text("Blink resumed")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(fg)
                Text(detail)
                    .font(.system(size: 11))
                    .foregroundStyle(fg.opacity(0.7))
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(bg)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

/// Interactive toast for calendar-driven pauses: an icon, a one-line title +
/// detail, and a single accent action button ("Undo" for an auto-pause,
/// "Pause" for a suggestion). Shares the styling of `FlowNudgeToastView`.
struct MeetingActionToastView: View {
    let theme: BlinkTheme
    let icon: String
    let title: String
    let detail: String
    let actionLabel: String
    let onAction: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let bg = theme.overlayBackground(for: colorScheme)
        let fg = theme.overlayText(for: colorScheme)
        let accent = theme.accent(for: colorScheme)

        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(accent)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(fg)
                    .lineLimit(1)
                Text(detail)
                    .font(.system(size: 11))
                    .foregroundStyle(fg.opacity(0.7))
                    .lineLimit(1)
            }

            Spacer()

            Button(action: onAction) {
                Text(actionLabel)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(theme.textOnAccent(for: colorScheme))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(accent)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(bg)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

private struct DebugToastView: View {
    let message: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "ant")
                .font(.system(size: 12))
                .foregroundStyle(.orange)
            Text(message)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(.white)
                .lineLimit(2)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.9))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Previews

#Preview("Toast") {
    ToastView(theme: .peach, onDone: {})
        .frame(width: 280, height: 72)
}

#Preview("Countdown") {
    CountdownPhaseView(theme: .midnight, onCountdownDone: {}, onSkip: {})
        .frame(width: 600, height: 400)
}

#Preview("Break Timer - Peach (default)") {
    BreakPhaseView(theme: .peach, model: BreakPhaseModel(), onComplete: {}, onSkip: {})
        .frame(width: 600, height: 500)
}

#Preview("Break Timer - Midnight (breathe)") {
    BreakPhaseView(theme: .midnight, model: BreakPhaseModel(), suggestion: .breathe, onComplete: {}, onSkip: {})
        .frame(width: 600, height: 500)
}

#Preview("Break Timer - Sage (walk)") {
    BreakPhaseView(theme: .sage, model: BreakPhaseModel(), suggestion: .takeAWalk, onComplete: {}, onSkip: {})
        .frame(width: 600, height: 500)
}

#Preview("Break Timer - Sand (touch grass)") {
    BreakPhaseView(theme: .sand, model: BreakPhaseModel(), suggestion: .touchGrass, onComplete: {}, onSkip: {})
        .frame(width: 600, height: 500)
}

// MARK: - Toast Previews

#Preview("Timer Extended Toast - Peach") {
    TimerExtendedToastView(theme: .peach, onDismiss: {}, onTakeBreak: {})
        .frame(width: 280, height: 72)
}

#Preview("Timer Extended Toast - Midnight") {
    TimerExtendedToastView(theme: .midnight, onDismiss: {}, onTakeBreak: {})
        .frame(width: 280, height: 72)
        .preferredColorScheme(.dark)
}

#Preview("Flow Nudge Toast - Peach") {
    FlowNudgeToastView(theme: .peach, message: "Focused — extended 10 min", onDismiss: {}, onTakeBreak: {})
        .frame(width: 320, height: 80)
}

#Preview("Flow Nudge Toast - Midnight") {
    FlowNudgeToastView(theme: .midnight, message: "Focused for 30 min — extended 10 min", onDismiss: {}, onTakeBreak: {})
        .frame(width: 320, height: 80)
        .preferredColorScheme(.dark)
}

#Preview("Flow Nudge Toast - Sage") {
    FlowNudgeToastView(theme: .sage, message: "Focused for 40 min — extended 10 min", onDismiss: {}, onTakeBreak: {})
        .frame(width: 320, height: 80)
}

#Preview("Debug Toast") {
    DebugToastView(message: "State: Normal → Flow")
        .frame(width: 320, height: 44)
}

#Preview("Debug Toast - Dark") {
    DebugToastView(message: "Timer reset: idle 185s >= 180s")
        .frame(width: 320, height: 44)
        .preferredColorScheme(.dark)
}

#Preview("All Toasts - Light") {
    VStack(spacing: 16) {
        TimerExtendedToastView(theme: .peach, onDismiss: {}, onTakeBreak: {})
            .frame(width: 280, height: 72)

        FlowNudgeToastView(theme: .peach, message: "Focused — extended 10 min", onDismiss: {}, onTakeBreak: {})
            .frame(width: 320, height: 80)

        DebugToastView(message: "State: Normal → Flow")
            .frame(width: 320, height: 44)
    }
    .padding(20)
    .frame(width: 380, height: 300)
}

#Preview("All Toasts - Dark") {
    VStack(spacing: 16) {
        TimerExtendedToastView(theme: .midnight, onDismiss: {}, onTakeBreak: {})
            .frame(width: 280, height: 72)

        FlowNudgeToastView(theme: .midnight, message: "Focused for 30 min — extended 10 min", onDismiss: {}, onTakeBreak: {})
            .frame(width: 320, height: 80)

        DebugToastView(message: "Timer reset: idle 185s >= 180s")
            .frame(width: 320, height: 44)
    }
    .padding(20)
    .frame(width: 380, height: 300)
    .preferredColorScheme(.dark)
}
