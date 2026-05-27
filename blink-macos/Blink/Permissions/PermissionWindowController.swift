import SwiftUI
import AppKit

/// Shows the permission guide — user manually adds Blink in Input Monitoring settings.
/// Auto-dismisses when permission is detected (either via the user clicking
/// "I've granted access" in the guide, or by a background poll that catches
/// the case where the user granted via the macOS system dialog instead).
final class PermissionWindowController {
    private let log = BlinkLog.permission
    private var window: NSWindow?
    private var grantPollTimer: Timer?
    var onPermissionGranted: (() -> Void)?

    func show(theme: BlinkTheme, troubleshooting: Bool = false, onGranted: @escaping () -> Void) {
        guard let screen = NSScreen.main else { return }
        self.onPermissionGranted = onGranted

        let windowWidth: CGFloat = 700
        let windowHeight: CGFloat = 420
        let visible = screen.visibleFrame
        let x = visible.midX - windowWidth / 2
        let y = visible.midY - windowHeight / 2

        let guideView: NSView
        if troubleshooting {
            guideView = NSHostingView(rootView: PermissionTroubleshootingView(
                theme: theme,
                onOpenSettings: {
                    PermissionManager.openInputMonitoringSettings()
                },
                onTryAgain: { [weak self] in
                    self?.checkAndDismiss()
                }
            ))
        } else {
            guideView = NSHostingView(rootView: PermissionGuideView(
                theme: theme,
                onOpenSettings: {
                    PermissionManager.openInputMonitoringSettings()
                },
                onConfirmGranted: { [weak self] in
                    self?.checkAndDismiss()
                }
            ))
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
        // Floating so the guide stays visible above the user's other windows
        // while they're toggling the permission in System Settings. The OS
        // Input Monitoring dialog uses .modalPanel and still appears on top.
        win.level = .floating
        win.hasShadow = true
        win.appearance = NSApp.effectiveAppearance
        win.contentView = guideView

        win.alphaValue = 0
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        UIActionLogger.windowOpened("PermissionGuide")

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.3
            win.animator().alphaValue = 1
        }

        self.window = win
        startGrantPolling()
    }

    /// Polls every 2 seconds for an external grant (user toggled Input Monitoring
    /// in System Settings without clicking "I've granted access" in our guide).
    /// `CGPreflightListenEventAccess` is cheap and never triggers a system prompt.
    private func startGrantPolling() {
        grantPollTimer?.invalidate()
        grantPollTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            if PermissionManager.isPermissionGranted() {
                self.log.info("Permission detected via background poll — dismissing window")
                self.grantPollTimer?.invalidate()
                self.grantPollTimer = nil
                self.dismiss()
                self.onPermissionGranted?()
            }
        }
    }

    private var checkAttempts = 0

    private func checkAndDismiss() {
        log.info("User tapped 'I've granted access' — checking (attempt \(checkAttempts + 1))")
        if PermissionManager.isPermissionGranted() {
            log.info("Permission confirmed — dismissing window")
            checkAttempts = 0
            grantPollTimer?.invalidate()
            grantPollTimer = nil
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
        grantPollTimer?.invalidate()
        grantPollTimer = nil
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
