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

        let windowWidth = screen.frame.width * 0.8
        let windowHeight = screen.frame.height * 0.8
        let visible = screen.visibleFrame
        // Centered — same focal point as the onboarding window so the
        // transition from onboarding → permission flow doesn't jump the
        // eye.
        let x = visible.midX - windowWidth / 2
        let y = visible.midY - windowHeight / 2

        let view = PermissionFlowView(theme: theme) { [weak self] basicMode in
            self?.dismiss()
            onResolved(basicMode)
        }

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
        win.appearance = NSApp.effectiveAppearance

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
