import SwiftUI
import AppKit

/// Controls the onboarding window lifecycle.
final class OnboardingWindowController {
    private var window: NSWindow?

    func show(themeManager: ThemeManager, onComplete: @escaping () -> Void) {
        guard let screen = NSScreen.main else { return }

        let visible = screen.visibleFrame
        let windowWidth = screen.frame.width * 0.8
        let windowHeight = screen.frame.height * 0.8

        // Center within the visible frame (excludes menu bar and dock)
        let x = visible.midX - windowWidth / 2
        let y = visible.midY - windowHeight / 2

        let windowFrame = NSRect(x: x, y: y, width: windowWidth, height: windowHeight)

        let isDark = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua

        let onboardingView = OnboardingView(
            themeManager: themeManager,
            isDarkMode: isDark,
            onComplete: { [weak self] in
                self?.dismiss()
                onComplete()
            }
        )

        let win = NSWindow(
            contentRect: windowFrame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        win.isOpaque = false
        win.backgroundColor = .clear
        win.level = .normal
        win.hasShadow = true
        win.appearance = NSApp.effectiveAppearance
        win.contentView = NSHostingView(rootView: onboardingView)
        win.makeKeyAndOrderFront(nil)

        NSApp.activate(ignoringOtherApps: true)

        self.window = win
    }

    private func dismiss() {
        guard let win = window else { return }
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.3
            win.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            win.orderOut(nil)
            self?.window = nil
        })
    }
}
