import Foundation
import AppKit
import BlinkCore

/// Monitors app switches and window title changes.
final class MacAppMonitor: AppActivitySource {
    var onAppSwitch: ((AppSwitchEvent) -> Void)?
    var onWindowTitleChange: (() -> Void)?

    private var observation: NSObjectProtocol?
    private var titlePollTimer: Timer?
    private var lastWindowTitle: String?

    func startMonitoring() {
        // App switch via NSWorkspace notification
        observation = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  let bundleID = app.bundleIdentifier else { return }

            let event = AppSwitchEvent(
                timestamp: Date().timeIntervalSinceReferenceDate,
                appBundleID: bundleID
            )
            self?.onAppSwitch?(event)
        }

        // Poll window title every 5 seconds
        titlePollTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.checkWindowTitle()
        }
    }

    func stopMonitoring() {
        if let observation {
            NSWorkspace.shared.notificationCenter.removeObserver(observation)
        }
        observation = nil
        titlePollTimer?.invalidate()
        titlePollTimer = nil
    }

    private func checkWindowTitle() {
        guard let frontApp = NSWorkspace.shared.frontmostApplication,
              let pid = Optional(frontApp.processIdentifier) else { return }

        let appRef = AXUIElementCreateApplication(pid)
        var windowValue: AnyObject?
        guard AXUIElementCopyAttributeValue(appRef, kAXFocusedWindowAttribute as CFString, &windowValue) == .success,
              let window = windowValue else { return }

        // AXUIElement is a CoreFoundation type — verify type ID before casting
        let axWindow = window as! AXUIElement  // safe: AXUIElementCopyAttributeValue with kAXFocusedWindowAttribute always returns AXUIElement
        guard CFGetTypeID(axWindow) == AXUIElementGetTypeID() else { return }

        var titleValue: AnyObject?
        guard AXUIElementCopyAttributeValue(axWindow, kAXTitleAttribute as CFString, &titleValue) == .success,
              let title = titleValue as? String else { return }

        if title != lastWindowTitle {
            lastWindowTitle = title
            onWindowTitleChange?()
        }
    }

    deinit {
        stopMonitoring()
    }
}
