import SwiftUI
import AppKit

/// Shows the Launch HUD in a borderless window at the top-right of the
/// main screen. Auto-dismisses after `visibleSeconds`. Clicking the HUD
/// dismisses it immediately (and notifies via `onTap`).
///
/// This replaces the auto-open-menu-bar-popup behavior in
/// `AppState.startMonitoringAfterAllPermissions`. The popup auto-open
/// couldn't surface anything when the user's menu bar icon was hidden by
/// the notch / Bartender / overflow, so the HUD — which is its own
/// independent floating window — is the reliable "Blink is running" signal.
@MainActor
final class LaunchHUDWindowController {
    private var window: NSWindow?
    private var dismissTimer: Timer?

    /// `visibleSeconds = 6` is the default — long enough for the user to
    /// notice and read the message, short enough not to be intrusive.
    func show(theme: BlinkTheme, visibleSeconds: TimeInterval = 6.0, onTap: @escaping () -> Void) {
        guard let screen = NSScreen.main else { return }

        let windowWidth: CGFloat = 320
        let windowHeight: CGFloat = 78
        let visible = screen.visibleFrame
        // Anchor to TOP-RIGHT — visually near where the user's menu bar
        // icon would be. 20pt margin from the right edge, 12pt below the
        // top of the visible area (visible area excludes menu bar, so
        // this lands just below the menu bar itself).
        let x = visible.maxX - windowWidth - 20
        let y = visible.maxY - windowHeight - 12

        let hud = LaunchHUDView(theme: theme) { [weak self] in
            self?.dismiss(animated: true)
            onTap()
        }

        let win = NSPanel(
            contentRect: NSRect(x: x, y: y, width: windowWidth, height: windowHeight),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        win.isReleasedWhenClosed = false
        win.isOpaque = false
        win.backgroundColor = .clear
        win.hasShadow = false  // Shadow is drawn by the SwiftUI view
        win.level = .floating  // Sit above regular windows so it's visible during launch
        win.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        win.appearance = NSApp.effectiveAppearance
        win.ignoresMouseEvents = false

        let hosting = NSHostingView(rootView: hud)
        hosting.frame = NSRect(x: 0, y: 0, width: windowWidth, height: windowHeight)
        hosting.autoresizingMask = [.width, .height]
        win.contentView = hosting

        win.alphaValue = 0
        win.orderFrontRegardless()  // .nonactivatingPanel won't steal focus
        UIActionLogger.windowOpened("LaunchHUD")

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.35
            win.animator().alphaValue = 1
        }

        self.window = win

        // Schedule auto-dismiss
        dismissTimer?.invalidate()
        dismissTimer = Timer.scheduledTimer(withTimeInterval: visibleSeconds, repeats: false) { [weak self] _ in
            Task { @MainActor in self?.dismiss(animated: true) }
        }
    }

    func dismiss(animated: Bool) {
        guard let win = window else { return }
        dismissTimer?.invalidate()
        dismissTimer = nil
        UIActionLogger.windowClosed("LaunchHUD")

        if animated {
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.3
                win.animator().alphaValue = 0
            }, completionHandler: { [weak self] in
                // NSAnimationContext's completion handler is @Sendable but
                // fires on the main thread — hop to MainActor to satisfy
                // Swift 6 isolation checks without changing runtime behavior.
                MainActor.assumeIsolated {
                    win.orderOut(nil)
                    self?.window = nil
                }
            })
        } else {
            win.orderOut(nil)
            window = nil
        }
    }
}
