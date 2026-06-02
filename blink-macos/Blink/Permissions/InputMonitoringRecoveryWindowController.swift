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
    private var closeDelegate: SetupWindowCloseDelegate?

    /// `onResolved` fires once the user resolves the recovery. The
    /// `basicMode` argument is true when the user explicitly skipped
    /// the re-grant (chose to run the basic timer instead), false when
    /// IM was successfully re-granted (detected via the page's internal
    /// polling or "I've granted access" check). `onClose` fires when they
    /// close the window without resolving — AppState defaults to Simple mode.
    func show(theme: BlinkTheme, onResolved: @escaping (_ basicMode: Bool) -> Void, onClose: @escaping () -> Void) {
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
            onComplete: { [weak self] basicMode in
                self?.dismiss()
                onResolved(basicMode)
            }
        )

        // Closable titled setup window. The user can re-grant, use the in-page
        // "Use Simple timer mode" button, or close it (which defaults to Simple
        // mode via the onClose handler).
        let win = NSWindow.makeSetupWindow(
            contentRect: NSRect(x: x, y: y, width: windowWidth, height: windowHeight),
            title: "Blink — Input Monitoring"
        )
        win.hasShadow = true
        win.appearance = NSApp.effectiveAppearance

        let closeDelegate = SetupWindowCloseDelegate { [weak self] in
            self?.dismiss()
            onClose()
        }
        win.delegate = closeDelegate
        self.closeDelegate = closeDelegate

        let hosting = NSHostingView(rootView: page)
        hosting.frame = NSRect(x: 0, y: 0, width: windowWidth, height: windowHeight)
        hosting.autoresizingMask = [.width, .height]
        win.contentView = hosting

        // Show in the Dock for the duration so the user can recover the
        // window via the Dock icon if they tab away.
        NSApp.setActivationPolicy(.regular)

        win.alphaValue = 0
        win.surfaceAtLaunch()
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
