import AppKit
import os

private let log = Logger(subsystem: "com.blink20.app", category: "MenuBar")

/// Provides programmatic control over the SwiftUI MenuBarExtra popup.
/// Uses NSStatusItem.button.performClick to toggle the window — same technique
/// as MenuBarExtraAccess (App Store safe).
@MainActor
final class MenuBarController {
    static let shared = MenuBarController()

    private(set) var statusItem: NSStatusItem?

    /// Call once after a short delay post-launch (~0.5s) to find the status item.
    func findStatusItem() {
        let allWindows = NSApp.windows
        log.info("findStatusItem: \(allWindows.count) windows")
        for win in allWindows {
            log.info("  window: \(win.className) title='\(win.title)'")
        }

        // Try NSStatusBarWindow first, then fall back to broader search
        let statusBarWindows = allWindows.filter {
            $0.className.contains("StatusBar") || $0.className.contains("StatusItem")
        }
        log.info("Status bar windows: \(statusBarWindows.count)")

        statusItem = allWindows
            .compactMap { win -> NSStatusItem? in
                guard let item = win.value(forKey: "statusItem") as? NSStatusItem else { return nil }
                log.info("  found statusItem in \(win.className), item class=\(type(of: item))")
                return item
            }
            .first
    }

    var isPresented: Bool {
        statusItem?.button?.state != .off
    }

    func open() {
        guard let button = statusItem?.button else { return }
        // First click may just create the window lazily.
        // Send the click action directly to the button's target instead of performClick.
        NSApp.activate(ignoringOtherApps: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            // Use the button's action/target to toggle the window
            if let action = button.action, let target = button.target {
                log.info("open: sending action \(NSStringFromSelector(action)) to \(type(of: target))")
                NSApp.sendAction(action, to: target, from: button)
            } else {
                log.info("open: no action/target, using performClick")
                button.performClick(button)
            }
        }
    }

    func close() {
        guard let button = statusItem?.button, isPresented else { return }
        button.performClick(button)
    }

    func toggle() {
        statusItem?.button?.performClick(statusItem?.button)
    }
}
