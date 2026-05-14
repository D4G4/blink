import SwiftUI
import AppKit

/// Shows the permission guide screen.
/// Tries the system prompt first (works for unsandboxed/DMG builds).
/// If sandboxed, shows step-by-step instructions.
final class PermissionWindowController {
    private var window: NSWindow?

    func show(theme: BlinkTheme, onContinue: @escaping () -> Void) {
        guard let screen = NSScreen.main else { return }

        // Try the system prompt first (works for unsandboxed/DMG builds)
        PermissionManager.requestAccessibility()

        // Check after a short delay if permission was granted
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            if PermissionManager.isAccessibilityGranted() {
                // System prompt worked — done, no window needed
                onContinue()
            } else {
                // Prompt didn't appear (sandboxed) — show step-by-step guide
                self?.showGuide(theme: theme, screen: screen)
            }
        }
    }

    private func showGuide(theme: BlinkTheme, screen: NSScreen) {
        let windowWidth: CGFloat = 700
        let windowHeight: CGFloat = 480
        let visible = screen.visibleFrame
        let x = visible.midX - windowWidth / 2
        let y = visible.midY - windowHeight / 2

        let guideView = PermissionGuideView(
            theme: theme,
            onOpenSettings: {
                PermissionManager.openAccessibilitySettings()
            }
        )

        let win = NSWindow(
            contentRect: NSRect(x: x, y: y, width: windowWidth, height: windowHeight),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        win.isOpaque = false
        win.backgroundColor = .clear
        win.level = .normal  // don't stay on top — let user interact with Settings
        win.hasShadow = true
        win.appearance = NSApp.effectiveAppearance
        win.contentView = NSHostingView(rootView: guideView)

        win.alphaValue = 0
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.3
            win.animator().alphaValue = 1
        }

        self.window = win
    }

    func dismiss() {
        guard let win = window else { return }
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.3
            win.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            win.orderOut(nil)
            self?.window = nil
        })
    }
}
