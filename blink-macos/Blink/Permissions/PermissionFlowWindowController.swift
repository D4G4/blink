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
    private var closeDelegate: SetupWindowCloseDelegate?

    /// `onResolved` fires when the user resolves the flow by choosing — Simple
    /// (basicMode true) or granting IM (false). `onClose` fires when they close
    /// the window without choosing (red button / Cmd-W) — AppState defaults to
    /// Simple mode and shows a confirming HUD.
    ///
    /// `forceLight`: true only when shown immediately after onboarding (which
    /// is forced light) — keeps the window light to avoid a light→dark jump.
    /// false (the default, standalone launch) honors the system appearance.
    ///
    /// `startAtPermissions`: skip the detection-mode choice page and open on
    /// the mic step (used when the user already chose Smart in Settings).
    func show(theme: BlinkTheme,
              forceLight: Bool = false,
              startAtPermissions: Bool = false,
              onResolved: @escaping (_ basicMode: Bool) -> Void,
              onClose: @escaping () -> Void) {
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

        // Appearance: standalone launches honor the system (light/dark
        // titlebar + gradient — the pages render both schemes, see the
        // Midnight previews). When shown straight out of onboarding
        // (forceLight), stay light to match the forced-light onboarding window
        // and avoid a light→dark jump mid-flow.
        let view = PermissionFlowView(
            theme: theme,
            initialStep: startAtPermissions ? .microphone : .detectionMode
        ) { [weak self] basicMode in
            self?.dismiss()
            onResolved(basicMode)
        }
        .preferredColorScheme(forceLight ? .light : nil)

        // Closable titled setup window (traffic lights + Dock icon + native
        // window management). Closing it (without choosing) defaults to Simple
        // mode via the onClose handler.
        let win = NSWindow.makeSetupWindow(
            contentRect: NSRect(x: x, y: y, width: windowWidth, height: windowHeight),
            title: "Set Up Blink"
        )
        win.hasShadow = true
        win.appearance = forceLight ? NSAppearance(named: .aqua) : nil

        let closeDelegate = SetupWindowCloseDelegate { [weak self] in
            self?.dismiss()
            onClose()
        }
        win.delegate = closeDelegate
        self.closeDelegate = closeDelegate

        let hosting = NSHostingView(rootView: view)
        hosting.frame = NSRect(x: 0, y: 0, width: windowWidth, height: windowHeight)
        hosting.autoresizingMask = [.width, .height]
        win.contentView = hosting

        // Show Blink in the Dock for the duration so the user can recover the
        // window via the Dock icon if it gets buried (AppDelegate's
        // applicationShouldHandleReopen re-fronts it).
        NSApp.setActivationPolicy(.regular)

        win.alphaValue = 0
        win.surfaceAtLaunch()
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
