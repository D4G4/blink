import SwiftUI
import AppKit

/// Shows the permission guide — user manually adds Blink in Accessibility settings.
/// Auto-dismissed by AppState polling when permission is detected.
final class PermissionWindowController {
    private var window: NSWindow?

    func show(theme: BlinkTheme, onSettingsOpened: (() -> Void)? = nil) {
        guard let screen = NSScreen.main else { return }

        let windowWidth: CGFloat = 700
        let windowHeight: CGFloat = 420
        let visible = screen.visibleFrame
        let x = visible.midX - windowWidth / 2
        let y = visible.midY - windowHeight / 2

        let guideView = PermissionGuideView(
            theme: theme,
            onOpenSettings: {
                PermissionManager.openAccessibilitySettings()
                // Start polling only after user opens settings
                onSettingsOpened?()
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
        win.level = .normal
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
