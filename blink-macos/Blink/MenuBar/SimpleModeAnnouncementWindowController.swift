import SwiftUI
import AppKit

/// Shows the one-time Simple-mode announcement HUD at the top-right of
/// the main screen, near the menu bar. Same window pattern as
/// LaunchHUDWindowController: borderless NSPanel, .nonactivatingPanel,
/// .floating level so it surfaces above other windows without stealing
/// focus.
@MainActor
final class SimpleModeAnnouncementWindowController {
    private var window: NSWindow?

    func show(theme: BlinkTheme, style: SimpleModeAnnouncementView.Style = .announce, onShowMe: @escaping () -> Void, onDismiss: @escaping () -> Void) {
        guard let screen = NSScreen.main else { return }

        let width: CGFloat = 360
        let height: CGFloat = 132
        let visible = screen.visibleFrame
        let x = visible.maxX - width - 20
        // Anchor 12pt below the top of the visible area. If the launch HUD
        // is also shown (same place), this HUD will overlap it briefly —
        // acceptable for a one-time announcement; users will dismiss both.
        let y = visible.maxY - height - 12

        let view = SimpleModeAnnouncementView(
            theme: theme,
            style: style,
            onShowMe: { [weak self] in
                self?.dismiss(animated: true)
                onShowMe()
            },
            onDismiss: { [weak self] in
                self?.dismiss(animated: true)
                onDismiss()
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
        win.hasShadow = false
        win.level = .floating
        win.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        win.appearance = NSApp.effectiveAppearance
        win.ignoresMouseEvents = false

        let hosting = NSHostingView(rootView: view)
        hosting.frame = NSRect(x: 0, y: 0, width: width, height: height)
        hosting.autoresizingMask = [.width, .height]
        win.contentView = hosting

        win.alphaValue = 0
        win.orderFrontRegardless()
        UIActionLogger.windowOpened("SimpleModeAnnouncement")

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.35
            win.animator().alphaValue = 1
        }

        self.window = win
    }

    func dismiss(animated: Bool) {
        guard let win = window else { return }
        UIActionLogger.windowClosed("SimpleModeAnnouncement")

        if animated {
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.3
                win.animator().alphaValue = 0
            }, completionHandler: { [weak self] in
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
