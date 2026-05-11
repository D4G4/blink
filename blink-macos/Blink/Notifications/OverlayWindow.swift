import SwiftUI
import AppKit

/// Manages the break overlay flow:
/// 1. Mini toast in bottom-right (3s heads-up)
/// 2. Fullscreen countdown (3s)
/// 3. Break timer (20s)
final class OverlayWindowController {
    private var toastWindow: NSWindow?
    private var fullscreenWindow: NSWindow?
    private var keyMonitor: Any?
    
    private var theme: BlinkTheme {
        UserDefaults.standard.bool(forKey: "useDarkOverlay")
        ? .dark
        : ThemeManager.shared.current
    }
    
    func showBreak(onComplete: @escaping () -> Void, onSkip: @escaping () -> Void) {
        showToast(onToastDone: { [weak self] in
            self?.dismissToast()
            self?.showBreakTimer(onComplete: onComplete, onSkip: onSkip)
        })
    }
    
    /// Show a "timer extended" toast when flow is detected.
    /// User can dismiss (keep extension) or tap "Take break now".
    func showTimerExtendedToast(onTakeBreakNow: @escaping () -> Void) {
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
            onDismiss: { [weak self] in self?.dismissToast() },
            onTakeBreak: { [weak self] in
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
        
        // Auto-dismiss after 5 seconds if not interacted with
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            self?.dismissToast()
        }
    }
    
    /// Show a debug toast with a reason for timer reset or state change.
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
    
    private func showBreakTimer(onComplete: @escaping () -> Void, onSkip: @escaping () -> Void) {
        guard let screen = NSScreen.main else { return }
        
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
        win.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        win.alphaValue = 0
        self.fullscreenWindow = win
        
        let skipAction = { [weak self] in
            self?.dismissFullscreen()
            onSkip()
        }
        let breakModel = BreakPhaseModel()
        let breakView = BreakPhaseView(
            theme: theme,
            model: breakModel,
            onComplete: { [weak self] in
                self?.dismissFullscreen()
                onComplete()
            },
            onSkip: skipAction
        )
        
        // NSEvent local monitor for keyboard — .onKeyPress doesn't work in borderless windows
        removeKeyMonitor()
        currentKeyHandler = KeyEventHandler(
            onEscape: skipAction,
            onRightArrow: { [weak breakModel] in breakModel?.extend() }
        )
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if self?.currentKeyHandler?.handle(event) == true {
                return nil // consumed
            }
            return event
        }
        
        win.contentView = NSHostingView(rootView: AnyView(breakView))
        win.makeKeyAndOrderFront(nil)
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            win.animator().alphaValue = 1
        }
    }
    
    private var currentKeyHandler: KeyEventHandler?
    
    private func removeKeyMonitor() {
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
        currentKeyHandler = nil
    }
    
    private func dismissFullscreen() {
        removeKeyMonitor()
        guard let win = fullscreenWindow else { return }
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.3
            win.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            win.orderOut(nil)
            self?.fullscreenWindow = nil
        })
    }
    
    func dismiss() {
        dismissToast()
        dismissFullscreen()
    }
}

// MARK: - Toast (bottom-right heads-up)

private struct ToastView: View {
    let theme: BlinkTheme
    let onDone: () -> Void
    
    @State private var count: Int = 3
    @State private var timer: Timer?
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "eye")
                .font(.system(size: 20))
                .foregroundStyle(.primary)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Break in \(count)s")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.primary)
            }
            
            Spacer()
            
            ZStack {
                Circle()
                    .stroke(theme.accent.opacity(0.3), lineWidth: 2)
                    .frame(width: 28, height: 28)
                Circle()
                    .trim(from: 0, to: CGFloat(count) / 3.0)
                    .stroke(theme.accent, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .frame(width: 28, height: 28)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: count)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial)
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

private struct TimerExtendedToastView: View {
    let theme: BlinkTheme
    let onDismiss: () -> Void
    let onTakeBreak: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 14))
                    .foregroundStyle(theme.accent(for: colorScheme))
                
                Text("In flow — timer extended")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.primary)
            }
            
            HStack {
                Spacer()
                Button {
                    onTakeBreak()
                } label: {
                    Text("Take break now")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(theme.accent(for: colorScheme))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
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

private struct CountdownPhaseView: View {
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
                    .foregroundStyle(fg.opacity(0.7))
                
                Text("\(count)")
                    .font(.system(size: 96, weight: .ultraLight, design: .rounded))
                    .foregroundStyle(theme.accent)
                    .scaleEffect(scale)
                    .animation(.easeOut(duration: 0.3), value: count)
                
                Text("esc to skip")
                    .font(.system(size: 13))
                    .foregroundStyle(fg.opacity(0.3))
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

private final class BreakPhaseModel: ObservableObject {
    @Published var remaining: Int = 20
    @Published var total: Int = 20
    @Published var showExtendHint: Bool = false
    var timer: Timer?
    
    func extend() {
        remaining += 20
        total += 20
        withAnimation(.easeOut(duration: 0.4)) { showExtendHint = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            withAnimation { self?.showExtendHint = false }
        }
    }
    
    func startTimer(onComplete: @escaping () -> Void) {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            if self.remaining > 0 { self.remaining -= 1 } else { self.stopTimer(); onComplete() }
        }
    }
    
    func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}

// MARK: - Break timer (20s)

private struct BreakPhaseView: View {
    let theme: BlinkTheme
    @ObservedObject var model: BreakPhaseModel
    let onComplete: () -> Void
    let onSkip: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        let bg = theme.overlayBackground(for: colorScheme)
        let fg = theme.overlayText(for: colorScheme)
        ZStack {
            bg.ignoresSafeArea()
            
            ZStack(alignment: .topTrailing) {
                VStack(spacing: 40) {
                    Text("Look at something far away")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(fg)

                    ZStack {
                        Circle()
                            .stroke(theme.accent.opacity(0.15), lineWidth: 4)
                            .frame(width: 160, height: 160)

                        Circle()
                            .trim(from: 0, to: CGFloat(model.remaining) / CGFloat(model.total))
                            .stroke(theme.accent, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                            .frame(width: 160, height: 160)
                            .rotationEffect(.degrees(-90))
                            .animation(.linear(duration: 1), value: model.remaining)

                        Text("\(model.remaining)")
                            .font(.system(size: 64, weight: .ultraLight, design: .monospaced))
                            .foregroundStyle(fg)
                    }

                    if model.showExtendHint {
                        Text("+20s")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(theme.accent)
                            .transition(.opacity.combined(with: .scale))
                    }

                    HStack(spacing: 32) {
                        KeyHintView(key: "esc", label: "Skip break", theme: theme)
                        KeyHintView(key: "→", label: "Extend 20s", theme: theme)
                    }
                    .padding(.top, 16)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                // Mini 20-feet badge in top right
                VStack(spacing: 6) {
                    Image(systemName: "eye")
                        .font(.system(size: 14))
                        .foregroundStyle(theme.accent)
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text("20")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(fg)
                        Text("ft")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(fg.opacity(0.5))
                    }
                }
                .padding(10)
                .background(theme.accent.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding(.top, 28)
                .padding(.trailing, 28)
            }
        }
        .onAppear { model.startTimer(onComplete: onComplete) }
        .onDisappear { model.stopTimer() }
    }
}

// MARK: - Key hint component

private struct KeyHintView: View {
    let key: String
    let label: String
    let theme: BlinkTheme
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        let fg = theme.overlayText(for: colorScheme)
        HStack(spacing: 10) {
            Text(key)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(fg.opacity(0.9))
                .frame(minWidth: 36, minHeight: 28)
                .padding(.horizontal, 8)
                .background(theme.accent.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(theme.accent.opacity(0.3), lineWidth: 1)
                )
            
            Text(label)
                .font(.system(size: 15))
                .foregroundStyle(fg.opacity(0.5))
        }
    }
}

// MARK: - Debug toast

private struct DebugToastView: View {
    let message: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "ant")
                .font(.system(size: 12))
                .foregroundStyle(.orange)
            Text(message)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(.primary)
                .lineLimit(2)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
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

#Preview("Break Timer - Peach") {
    BreakPhaseView(theme: .peach, model: BreakPhaseModel(), onComplete: {}, onSkip: {})
        .frame(width: 600, height: 500)
}

#Preview("Break Timer - Midnight") {
    BreakPhaseView(theme: .midnight, model: BreakPhaseModel(), onComplete: {}, onSkip: {})
        .frame(width: 600, height: 500)
}

#Preview("Break Timer - Sage") {
    BreakPhaseView(theme: .sage, model: BreakPhaseModel(), onComplete: {}, onSkip: {})
        .frame(width: 600, height: 500)
}
