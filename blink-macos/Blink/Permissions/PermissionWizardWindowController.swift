import SwiftUI
import AppKit

/// Hosts the PermissionWizardView in a single borderless window that stays
/// open across both wizard steps (microphone → input monitoring). The
/// onComplete callback fires once both steps are resolved (granted or
/// explicitly skipped) — AppState uses that to start the engine.
final class PermissionWizardWindowController {
    private let log = BlinkLog.permission
    private var window: NSWindow?

    func show(theme: BlinkTheme, onComplete: @escaping () -> Void) {
        guard let screen = NSScreen.main else { return }

        let windowWidth: CGFloat = 700
        let windowHeight: CGFloat = 500
        let visible = screen.visibleFrame
        // Anchor to TOP-CENTER so the macOS TCC dialogs (which are system-
        // positioned around screen center) don't overlap with our window.
        let x = visible.midX - windowWidth / 2
        let y = visible.maxY - windowHeight - 40

        let wizard = PermissionWizardView(theme: theme) { [weak self] in
            self?.dismiss()
            onComplete()
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

        // Explicitly frame the NSHostingView and set autoresizing so the
        // SwiftUI view fills the window content area regardless of its
        // intrinsic size. Without this, the host view auto-sizes to the
        // SwiftUI view's ideal size (which for narrow text content can
        // collapse to a tall, thin strip).
        let hosting = NSHostingView(rootView: wizard)
        hosting.frame = NSRect(x: 0, y: 0, width: windowWidth, height: windowHeight)
        hosting.autoresizingMask = [.width, .height]
        win.contentView = hosting

        win.alphaValue = 0
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        UIActionLogger.windowOpened("PermissionWizard")

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.3
            win.animator().alphaValue = 1
        }

        self.window = win
    }

    func dismiss() {
        guard let win = window else { return }
        UIActionLogger.windowClosed("PermissionWizard")
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.3
            win.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            win.orderOut(nil)
            self?.window = nil
        })
    }
}
