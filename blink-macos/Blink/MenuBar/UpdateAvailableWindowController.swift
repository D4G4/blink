import SwiftUI
import AppKit

/// Floating top-right HUD that surfaces a new release detected by
/// UpdateChecker. Same NSPanel pattern as
/// SimpleModeAnnouncementWindowController + LaunchHUDWindowController:
/// borderless, .nonactivatingPanel so it doesn't steal focus, .floating
/// level so it sits above regular windows.
@MainActor
final class UpdateAvailableWindowController {
    private var window: NSWindow?

    func show(theme: BlinkTheme, version: String, installSource: UpdateChecker.InstallSource, onPrimary: @escaping () -> Void, onSkip: @escaping () -> Void) {
        guard let screen = NSScreen.main else { return }

        let width: CGFloat = 360
        let height: CGFloat = 132
        let visible = screen.visibleFrame
        let x = visible.maxX - width - 20
        // 12pt below the top edge, same anchor as Launch/Announcement
        // HUDs. Only one of these surfaces typically renders at a time;
        // if they overlap, the most recently-shown one wins z-order.
        let y = visible.maxY - height - 12

        let view = UpdateAvailableView(
            theme: theme,
            version: version,
            installSource: installSource,
            onPrimary: { [weak self] in
                self?.dismiss(animated: true)
                onPrimary()
            },
            onSkip: { [weak self] in
                self?.dismiss(animated: true)
                onSkip()
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
        UIActionLogger.windowOpened("UpdateAvailable")

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.35
            win.animator().alphaValue = 1
        }

        self.window = win
    }

    func dismiss(animated: Bool) {
        guard let win = window else { return }
        UIActionLogger.windowClosed("UpdateAvailable")

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
