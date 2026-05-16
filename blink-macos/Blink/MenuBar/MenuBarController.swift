import AppKit

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
        BlinkLog.menuBar.info("findStatusItem: \(allWindows.count) windows")
        for win in allWindows {
            BlinkLog.menuBar.info("  window: \(win.className) title='\(win.title)'")
        }

        let statusBarWindows = allWindows.filter {
            $0.className.contains("StatusBar") || $0.className.contains("StatusItem")
        }
        BlinkLog.menuBar.info("Status bar windows: \(statusBarWindows.count)")

        statusItem = allWindows
            .compactMap { win -> NSStatusItem? in
                guard let item = win.value(forKey: "statusItem") as? NSStatusItem else { return nil }
                BlinkLog.menuBar.info("  found statusItem in \(win.className), item class=\(type(of: item))")
                return item
            }
            .first
    }

    var isPresented: Bool {
        statusItem?.button?.state != .off
    }

    func open() {
        guard let button = statusItem?.button else { return }
        NSApp.activate(ignoringOtherApps: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            if let action = button.action, let target = button.target {
                BlinkLog.menuBar.info("open: sending action \(NSStringFromSelector(action)) to \(type(of: target))")
                NSApp.sendAction(action, to: target, from: button)
            } else {
                BlinkLog.menuBar.info("open: no action/target, using performClick")
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
