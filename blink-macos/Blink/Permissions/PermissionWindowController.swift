import SwiftUI
import AppKit

/// Shows the permission explanation screen, then the step-by-step guide if needed.
final class PermissionWindowController {
    private var window: NSWindow?

    func show(theme: BlinkTheme, onContinue: @escaping () -> Void) {
        guard let screen = NSScreen.main else { return }

        let windowWidth: CGFloat = 500
        let windowHeight: CGFloat = 650
        let visible = screen.visibleFrame
        let x = visible.midX - windowWidth / 2
        let y = visible.midY - windowHeight / 2

        let view = PermissionOnboardingView(theme: theme) { [weak self] in
            // Try the system prompt first (works for unsandboxed/DMG builds)
            PermissionManager.requestAccessibility()

            // Check after a short delay if permission was granted
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                if PermissionManager.isAccessibilityGranted() {
                    // System prompt worked (unsandboxed) — done
                    self?.dismiss()
                    onContinue()
                } else {
                    // Prompt didn't appear (sandboxed) — show step-by-step guide
                    self?.showGuide(theme: theme, onContinue: onContinue)
                }
            }
        }

        let win = NSWindow(
            contentRect: NSRect(x: x, y: y, width: windowWidth, height: windowHeight),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        win.isOpaque = false
        win.backgroundColor = .clear
        win.level = .floating
        win.hasShadow = true
        win.appearance = NSApp.effectiveAppearance
        win.contentView = NSHostingView(rootView: view)

        win.alphaValue = 0
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.3
            win.animator().alphaValue = 1
        }

        self.window = win
    }

    private func showGuide(theme: BlinkTheme, onContinue: @escaping () -> Void) {
        guard let win = window else { return }

        let guideView = PermissionGuideView(
            theme: theme,
            onOpenSettings: {
                PermissionManager.openAccessibilitySettings()
            }
        )

        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.2
            win.animator().alphaValue = 0
        }, completionHandler: {
            win.contentView = NSHostingView(rootView: guideView)
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.2
                win.animator().alphaValue = 1
            }
        })
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
