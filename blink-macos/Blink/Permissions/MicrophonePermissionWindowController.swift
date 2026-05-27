import SwiftUI
import AppKit

/// Shows the microphone permission explainer right after Input Monitoring
/// is granted, before the engine starts. The completion is called once
/// the user has either granted or skipped — the caller (AppState) uses
/// that to know it's safe to start monitoring.
final class MicrophonePermissionWindowController {
    private let log = BlinkLog.permission
    private var window: NSWindow?

    /// Completion is called with `true` if the user granted mic access,
    /// `false` if they skipped or denied. Either way, monitoring should
    /// start afterwards — the difference is just whether the "pause
    /// during calls" feature will function.
    func show(theme: BlinkTheme, completion: @escaping (Bool) -> Void) {
        guard let screen = NSScreen.main else { return }

        let windowWidth: CGFloat = 560
        let windowHeight: CGFloat = 440
        let visible = screen.visibleFrame
        // Anchor to the TOP of the screen (40pt below menu bar) so we don't
        // overlap with the macOS Microphone TCC dialog, which is system-
        // positioned around screen center. Centered horizontally.
        let x = visible.midX - windowWidth / 2
        let y = visible.maxY - windowHeight - 40

        let view = MicrophonePermissionView(
            theme: theme,
            onGrant: { [weak self] in
                Task { @MainActor in
                    let granted = await PermissionManager.requestMicrophoneAccess()
                    self?.dismiss()
                    completion(granted)
                }
            },
            onSkip: { [weak self] in
                self?.log.info("User skipped microphone permission")
                self?.dismiss()
                completion(false)
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
        // .normal so the system TCC dialog (when Grant Access fires it)
        // renders on top — same rationale as PermissionWindowController.
        win.level = .normal
        win.hasShadow = true
        win.appearance = NSApp.effectiveAppearance
        win.contentView = NSHostingView(rootView: view)

        win.alphaValue = 0
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        UIActionLogger.windowOpened("MicrophonePermission")

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.3
            win.animator().alphaValue = 1
        }

        self.window = win
    }

    func dismiss() {
        guard let win = window else { return }
        UIActionLogger.windowClosed("MicrophonePermission")
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.3
            win.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            win.orderOut(nil)
            self?.window = nil
        })
    }
}
