import SwiftUI
import AppKit

/// Hosts PermissionFlowView in a focused, centered window — the
/// post-onboarding permission setup flow (mic + IM) lives here so it
/// can be shown independently of the onboarding window. Used when:
///   - First launch after onboarding completes (theme + flow already set,
///     permissions not yet granted)
///   - App restart mid-permission setup (TCC grant restarted Blink)
///   - User wants to re-engage smart mode after opting into basic
final class PermissionFlowWindowController {
    private var window: NSWindow?

    /// `onResolved` fires once the user resolves the permission flow.
    /// `basicMode` is true if they explicitly opted out of Input
    /// Monitoring (basic-timer-only path), false if IM is granted.
    func show(theme: BlinkTheme, onResolved: @escaping (_ basicMode: Bool) -> Void) {
        guard let screen = NSScreen.main else { return }

        let visible = screen.visibleFrame
        // Scale with screen size but tighter than onboarding (the
        // permission pages have less content). Range:
        //   - min 720×620: tight fit for the rationale rows + buttons
        //   - max 980×800: doesn't get cavernous on 6K displays
        //   - target: 42% of screen width × 55% of screen height
        let windowWidth = max(720, min(visible.width * 0.42, 980))
        let windowHeight = max(620, min(visible.height * 0.55, 800))
        // Centered — same focal point as the onboarding window so the
        // transition from onboarding → permission flow doesn't jump the
        // eye.
        let x = visible.midX - windowWidth / 2
        let y = visible.midY - windowHeight / 2

        // Forced light to match the onboarding window — the permission flow
        // follows it immediately, so a system-following appearance here would
        // cause a light→dark jump mid-flow.
        let view = PermissionFlowView(theme: theme) { [weak self] basicMode in
            self?.dismiss()
            onResolved(basicMode)
        }
        .preferredColorScheme(.light)

        let win = KeyableBorderlessWindow(
            contentRect: NSRect(x: x, y: y, width: windowWidth, height: windowHeight),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        win.isReleasedWhenClosed = false
        win.isOpaque = false
        win.backgroundColor = .clear
        win.level = .normal
        win.hasShadow = true
        win.appearance = NSAppearance(named: .aqua)

        let hosting = NSHostingView(rootView: view)
        hosting.frame = NSRect(x: 0, y: 0, width: windowWidth, height: windowHeight)
        hosting.autoresizingMask = [.width, .height]
        win.contentView = hosting

        // Show Blink in the Dock for the duration so the user can
        // recover the window if it gets obscured by another app. Mirrors
        // what onboarding does.
        NSApp.setActivationPolicy(.regular)

        win.alphaValue = 0
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        UIActionLogger.windowOpened("PermissionFlow")

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.3
            win.animator().alphaValue = 1
        }

        self.window = win
    }

    func dismiss() {
        guard let win = window else { return }
        UIActionLogger.windowClosed("PermissionFlow")
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.3
            win.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            win.orderOut(nil)
            self?.window = nil
            NSApp.setActivationPolicy(.accessory)
        })
    }
}
