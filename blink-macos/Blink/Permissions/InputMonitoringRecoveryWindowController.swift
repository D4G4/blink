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

    /// `onResolved` fires once the user resolves the recovery. The
    /// `basicMode` argument is true when the user explicitly skipped
    /// the re-grant (chose to run the basic timer instead), false when
    /// IM was successfully re-granted (detected via the page's internal
    /// polling or "I've granted access" check).
    func show(theme: BlinkTheme, onResolved: @escaping (_ basicMode: Bool) -> Void) {
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

        let win = KeyableBorderlessWindow(
            contentRect: NSRect(x: x, y: y, width: windowWidth, height: windowHeight),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        win.isReleasedWhenClosed = false
        win.isOpaque = false
        win.backgroundColor = .clear
        // .floating — sits above normal user windows so it can't be
        // obscured by Xcode/browser/etc. Safe for recovery because we
        // never fire a new TCC dialog here (the grant is recorded, just
        // stale for this binary) — we only deeplink to Settings. The
        // onboarding wizard used .normal because its first-time CGRequest
        // CAN spawn an OS dialog, and a .floating wrapper would land
        // above it; recovery has no such risk.
        win.level = .floating
        win.hasShadow = true
        win.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
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
