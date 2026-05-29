import SwiftUI
import AppKit

/// Controls the onboarding window lifecycle.
final class OnboardingWindowController {
    private var window: NSWindow?

    func show(themeManager: ThemeManager, onComplete: @escaping () -> Void) {
        guard let screen = NSScreen.main else { return }

        let visible = screen.visibleFrame
        // Scale with screen size but clamp to a sane range:
        //   - min 900×680: below this the theme carousel + flow page
        //     content starts to clip on the 13" MacBook Air
        //   - max 1300×920: above this the design starts to feel
        //     cavernous (the content is laid out for ~900pt, anything
        //     much bigger is just empty margin)
        //   - target: 55% of screen width × 65% of screen height
        // Net effect: 13" MBA → ~900×680 (at the min), 27" 5K iMac /
        // 6K external → ~1300×920 (at the max), 14" MBP / 16" MBP in
        // between gracefully.
        let windowWidth = max(900, min(visible.width * 0.55, 1300))
        let windowHeight = max(680, min(visible.height * 0.65, 920))

        // Center within the visible frame (excludes menu bar and dock)
        let x = visible.midX - windowWidth / 2
        let y = visible.midY - windowHeight / 2

        let windowFrame = NSRect(x: x, y: y, width: windowWidth, height: windowHeight)

        // Onboarding always renders light (Peach-in-light is the brand's
        // first impression) regardless of system appearance.
        let onboardingView = OnboardingView(
            themeManager: themeManager,
            onComplete: { [weak self] in
                self?.dismiss()
                onComplete()
            }
        )
        .preferredColorScheme(.light)

        let win = KeyableBorderlessWindow(
            contentRect: windowFrame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        win.isOpaque = false
        win.backgroundColor = .clear
        win.level = .normal
        win.hasShadow = true
        win.appearance = NSAppearance(named: .aqua)
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
