import Foundation
import AppKit
import BlinkCore

/// Monitors app switches via NSWorkspace notifications.
/// No Accessibility dependency — purely workspace notifications.
final class MacAppMonitor: AppActivitySource {
    var onAppSwitch: ((AppSwitchEvent) -> Void)?

    private var observation: NSObjectProtocol?

    func startMonitoring() {
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
    }

    func stopMonitoring() {
        if let observation {
            NSWorkspace.shared.notificationCenter.removeObserver(observation)
        }
        observation = nil
    }

    deinit {
        stopMonitoring()
    }
}
