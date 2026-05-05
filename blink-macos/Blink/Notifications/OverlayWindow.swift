import SwiftUI
import AppKit

/// Manages the break overlay flow:
/// 1. Mini toast in bottom-right (3s heads-up)
/// 2. Fullscreen countdown (3s)
/// 3. Break timer (20s)
final class OverlayWindowController {
    private var toastWindow: NSWindow?
    private var fullscreenWindow: NSWindow?

    private var theme: BlinkTheme {
        UserDefaults.standard.bool(forKey: "useDarkOverlay")
            ? .dark
            : ThemeManager.shared.current
    }

    func showBreak(onComplete: @escaping () -> Void, onSkip: @escaping () -> Void) {
        showToast(onToastDone: { [weak self] in
            self?.dismissToast()
            self?.showFullscreenCountdown(onComplete: onComplete, onSkip: onSkip)
        })
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
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            win.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            win.orderOut(nil)
            self?.toastWindow = nil
        })
    }

    // MARK: - Phase 2 + 3: Fullscreen countdown → break timer

    private func showFullscreenCountdown(onComplete: @escaping () -> Void, onSkip: @escaping () -> Void) {
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

        let countdownView = CountdownPhaseView(
            theme: theme,
            onCountdownDone: { [weak self] in
                self?.transitionToBreak(onComplete: onComplete, onSkip: onSkip)
            },
            onSkip: { [weak self] in
                self?.dismissFullscreen()
                onSkip()
            }
        )

        win.contentView = NSHostingView(rootView: AnyView(countdownView))
        win.makeKeyAndOrderFront(nil)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            win.animator().alphaValue = 1
        }
    }

    private func transitionToBreak(onComplete: @escaping () -> Void, onSkip: @escaping () -> Void) {
        let breakView = BreakPhaseView(
            theme: theme,
            onComplete: { [weak self] in
                self?.dismissFullscreen()
                onComplete()
            },
            onSkip: { [weak self] in
                self?.dismissFullscreen()
                onSkip()
            }
        )
        fullscreenWindow?.contentView = NSHostingView(rootView: AnyView(breakView))
    }

    private func dismissFullscreen() {
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
        .onKeyPress(.escape) {
            stopTimer(); onSkip(); return .handled
        }
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

// MARK: - Break timer (20s)

private struct BreakPhaseView: View {
    let theme: BlinkTheme
    let onComplete: () -> Void
    let onSkip: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    @State private var remaining: Int = 20
    @State private var total: Int = 20
    @State private var timer: Timer?
    @State private var showExtendHint: Bool = false

    var body: some View {
        let bg = theme.overlayBackground(for: colorScheme)
        let fg = theme.overlayText(for: colorScheme)
        ZStack {
            bg.ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                Image(systemName: "eye")
                    .font(.system(size: 56, weight: .ultraLight))
                    .foregroundStyle(theme.accent.opacity(0.8))

                Text("Look at something far away")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(fg)

                ZStack {
                    Circle()
                        .stroke(theme.accent.opacity(0.15), lineWidth: 4)
                        .frame(width: 160, height: 160)

                    Circle()
                        .trim(from: 0, to: CGFloat(remaining) / CGFloat(total))
                        .stroke(theme.accent, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .frame(width: 160, height: 160)
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 1), value: remaining)

                    Text("\(remaining)")
                        .font(.system(size: 64, weight: .ultraLight, design: .monospaced))
                        .foregroundStyle(fg)
                }

                if showExtendHint {
                    Text("+20s")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(theme.accent)
                        .transition(.opacity.combined(with: .scale))
                }

                Spacer()

                VStack(spacing: 12) {
                    HStack(spacing: 32) {
                        KeyHintView(key: "esc", label: "Skip break", theme: theme)
                        KeyHintView(key: "→", label: "Extend 20s", theme: theme)
                    }
                }
                .padding(.bottom, 56)
            }
        }
        .onAppear { startTimer() }
        .onDisappear { stopTimer() }
        .onKeyPress(.escape) {
            stopTimer(); onSkip(); return .handled
        }
        .onKeyPress(.rightArrow) {
            extend(); return .handled
        }
    }

    private func extend() {
        remaining += 20
        total += 20
        withAnimation(.easeOut(duration: 0.4)) { showExtendHint = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation { showExtendHint = false }
        }
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if remaining > 0 { remaining -= 1 } else { stopTimer(); onComplete() }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
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
    BreakPhaseView(theme: .peach, onComplete: {}, onSkip: {})
        .frame(width: 600, height: 500)
}

#Preview("Break Timer - Midnight") {
    BreakPhaseView(theme: .midnight, onComplete: {}, onSkip: {})
        .frame(width: 600, height: 500)
}

#Preview("Break Timer - Sage") {
    BreakPhaseView(theme: .sage, onComplete: {}, onSkip: {})
        .frame(width: 600, height: 500)
}
