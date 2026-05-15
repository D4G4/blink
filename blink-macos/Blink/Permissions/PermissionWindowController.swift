import SwiftUI
import AppKit

/// Shows the permission guide — user manually adds Blink in Accessibility settings.
/// Dismissed when user clicks "I've granted access" and permission is confirmed.
final class PermissionWindowController {
    private var window: NSWindow?
    var onPermissionGranted: (() -> Void)?

    func show(theme: BlinkTheme, onGranted: @escaping () -> Void) {
        guard let screen = NSScreen.main else { return }
        self.onPermissionGranted = onGranted

        let windowWidth: CGFloat = 700
        let windowHeight: CGFloat = 420
        let visible = screen.visibleFrame
        let x = visible.midX - windowWidth / 2
        let y = visible.midY - windowHeight / 2

        let guideView = PermissionGuideView(
            theme: theme,
            onOpenSettings: {
                PermissionManager.openAccessibilitySettings()
            },
            onConfirmGranted: { [weak self] in
                self?.checkAndDismiss()
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

    private func checkAndDismiss() {
        if PermissionManager.isPermissionGranted() {
            dismiss()
            onPermissionGranted?()
        } else {
            // Show error in the guide — update the view's showError state
            // Since we can't easily update SwiftUI state from here,
            // re-create the view with error showing
            guard let win = window else { return }
            let theme = ThemeManager.shared.current
            let errorView = PermissionGuideView(
                theme: theme,
                onOpenSettings: {
                    PermissionManager.openAccessibilitySettings()
                },
                onConfirmGranted: { [weak self] in
                    self?.checkAndDismiss()
                }
            )
            // We need to trigger the error state — pass it as a binding or just shake the window
            let animation = CAKeyframeAnimation(keyPath: "position.x")
            animation.values = [0, -8, 8, -6, 6, -3, 3, 0].map { win.frame.origin.x + $0 }
            animation.duration = 0.4
            win.animations = ["frameOrigin": animation]
            win.animator().setFrameOrigin(win.frame.origin)
        }
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
