import SwiftUI
import AppKit

/// Shows the permission guide — user manually adds Blink in Accessibility settings.
/// Dismissed when user clicks "I've granted access" and permission is confirmed.
final class PermissionWindowController {
    private let log = BlinkLog.permission
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
        win.isReleasedWhenClosed = false
        win.isOpaque = false
        win.backgroundColor = .clear
        win.level = .normal
        win.hasShadow = true
        win.appearance = NSApp.effectiveAppearance
        win.contentView = NSHostingView(rootView: guideView)

        win.alphaValue = 0
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        UIActionLogger.windowOpened("PermissionGuide")

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.3
            win.animator().alphaValue = 1
        }

        self.window = win
    }

    private var checkAttempts = 0

    private func checkAndDismiss() {
        log.info("User tapped 'I've granted access' — checking (attempt \(checkAttempts + 1))")
        if PermissionManager.isPermissionGranted() {
            log.info("Permission confirmed — dismissing window")
            checkAttempts = 0
            dismiss()
            onPermissionGranted?()
            return
        }

        // TCC grant can take a moment to propagate — retry a few times before shaking
        if checkAttempts < 3 {
            checkAttempts += 1
            log.info("Permission not yet granted, retrying in 0.5s (attempt \(checkAttempts)/3)")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.checkAndDismiss()
            }
            return
        }

        log.info("Permission still denied after 3 retries — shaking window")
        checkAttempts = 0
        guard let win = window else { return }
        // Shake the window to indicate permission not yet granted
        let origin = win.frame.origin
        let offsets: [CGFloat] = [-8, 8, -6, 6, -3, 3, 0]
        let step = 0.4 / Double(offsets.count)
        for (i, dx) in offsets.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + step * Double(i)) {
                win.setFrameOrigin(NSPoint(x: origin.x + dx, y: origin.y))
            }
        }
    }

    func dismiss() {
        guard let win = window else { return }
        UIActionLogger.windowClosed("PermissionGuide")
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.3
            win.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            win.orderOut(nil)
            self?.window = nil
        })
    }
}
