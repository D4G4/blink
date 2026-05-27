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
        Log.i("findStatusItem: \(allWindows.count) windows")
        for win in allWindows {
            Log.i("  window: \(win.className) title='\(win.title)'")
        }

        let statusBarWindows = allWindows.filter {
            $0.className.contains("StatusBar") || $0.className.contains("StatusItem")
        }
        Log.i("Status bar windows: \(statusBarWindows.count)")

        statusItem = allWindows
            .compactMap { win -> NSStatusItem? in
                guard let item = win.value(forKey: "statusItem") as? NSStatusItem else { return nil }
                Log.i("  found statusItem in \(win.className), item class=\(type(of: item))")
                return item
            }
            .first
    }

    var isPresented: Bool {
        statusItem?.button?.state != .off
    }

    /// Opens the MenuBarExtra popover by simulating a click on the status
    /// item button. `performClick(nil)` is the only path that reliably
    /// triggers the full popover-open side effects in SwiftUI's
    /// `MenuBarExtra(style: .window)` — sending the `toggleWindow:`
    /// action directly via `NSApp.sendAction` dispatches the selector
    /// but the popover never visibly appears (the popover needs the
    /// click cycle's button state change + window-activation handshake
    /// that `sendAction` skips). Verified empirically in 9:58 AM session
    /// log on 2026-05-27: sendAction logged, no popover shown.
    func open(attempt: Int = 0) {
        guard let button = statusItem?.button else {
            Log.i("MenuBarController.open: button nil at attempt \(attempt + 1)")
            return
        }
        if button.state == .on {
            Log.i("MenuBarController.open: popover already open")
            return
        }
        Log.i("MenuBarController.open: performClick(nil), pre-state=\(button.state.rawValue), attempt=\(attempt + 1)")
        button.performClick(nil)

        // Verify the click landed. If `state` didn't flip to .on, the
        // popover didn't open — retry up to 3 times with a brief delay
        // (covers the race where the status item exists but SwiftUI's
        // popover is still wiring up its window).
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self else { return }
            let post = self.statusItem?.button?.state ?? .off
            Log.i("MenuBarController.open: post-click state=\(post.rawValue)")
            if post != .on && attempt < 3 {
                self.open(attempt: attempt + 1)
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
