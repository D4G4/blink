import SwiftUI
import AppKit

/// Hosts `InputMonitoringPermissionPage` in `staleGrant` mode for the
/// post-onboarding "permission says granted but the tap won't create"
/// recovery flow (typical after a Blink update changes the binary's
/// CDHash, leaving the TCC grant pointed at the previous binary).
///
/// Replaces the legacy `PermissionWindowController` + the older
/// `PermissionGuideView` / `PermissionTroubleshootingView` pair, so the
/// recovery UI matches the polished onboarding aesthetic instead of
/// looking like a leftover from the previous design.
@MainActor
final class InputMonitoringRecoveryWindowController {
    private var window: NSWindow?

    /// `onGranted` fires once IM is granted (detected via the page's
    /// internal polling or "I've granted access" check). AppState uses
    /// it to restart monitoring.
    func show(theme: BlinkTheme, onGranted: @escaping () -> Void) {
        guard let screen = NSScreen.main else { return }

        let windowWidth: CGFloat = 700
        let windowHeight: CGFloat = 540
        let visible = screen.visibleFrame
        // Centered horizontally + vertically — same focal point as the
        // onboarding window so there's no eye jump.
        let x = visible.midX - windowWidth / 2
        let y = visible.midY - windowHeight / 2

        let page = InputMonitoringPermissionPage(
            theme: theme,
            mode: .staleGrant,
            onBack: nil,
            onComplete: { [weak self] _ in
                self?.dismiss()
                onGranted()
            }
        )

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

        let hosting = NSHostingView(rootView: page)
        hosting.frame = NSRect(x: 0, y: 0, width: windowWidth, height: windowHeight)
        hosting.autoresizingMask = [.width, .height]
        win.contentView = hosting

        // Show in the Dock for the duration so the user can recover the
        // window if they tab away. Mirrors the wizard's approach during
        // onboarding.
        NSApp.setActivationPolicy(.regular)

        win.alphaValue = 0
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        UIActionLogger.windowOpened("IMRecovery")

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.3
            win.animator().alphaValue = 1
        }

        self.window = win
    }

    func dismiss() {
        guard let win = window else { return }
        UIActionLogger.windowClosed("IMRecovery")
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.3
            win.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            MainActor.assumeIsolated {
                win.orderOut(nil)
                self?.window = nil
                NSApp.setActivationPolicy(.accessory)
            }
        })
    }
}
