import SwiftUI
import AppKit

/// Shows the Launch HUD in a borderless window at the top-right of the
/// main screen, visually near where the user's menu bar icon would be.
///
/// This replaces the auto-open-menu-bar-popup behavior in
/// `AppState.startMonitoringAfterAllPermissions`. The popup auto-open
/// couldn't surface anything when the user's menu bar icon was hidden by
/// the notch / Bartender / overflow, so the HUD — which is its own
/// independent floating window — is the reliable "Blink is running" signal.
///
/// The HUD is persistent (no auto-dismiss). `onFound` fires when the user
/// taps "I've found it"; `onCantFind` when they tap "Can't find it".
@MainActor
final class LaunchHUDWindowController {
    private var window: NSWindow?

    func show(theme: BlinkTheme, onFound: @escaping () -> Void, onCantFind: @escaping () -> Void) {
        guard let screen = NSScreen.main else { return }

        let width: CGFloat = 340
        let height: CGFloat = 124
        let visible = screen.visibleFrame
        // Anchor to TOP-RIGHT — near where the menu bar icon would be.
        // 20pt margin from the right edge, 12pt below the top of the
        // visible area (which already excludes the menu bar).
        let x = visible.maxX - width - 20
        let y = visible.maxY - height - 12

        let view = LaunchHUDView(
            theme: theme,
            onFound: { [weak self] in
                self?.dismiss(animated: true)
                onFound()
            },
            onCantFind: { [weak self] in
                self?.dismiss(animated: true)
                onCantFind()
            }
        )

        let win = NSPanel(
            contentRect: NSRect(x: x, y: y, width: width, height: height),
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

        let hosting = NSHostingView(rootView: view)
        hosting.frame = NSRect(x: 0, y: 0, width: width, height: height)
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
    }

    func dismiss(animated: Bool) {
        guard let win = window else { return }
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
