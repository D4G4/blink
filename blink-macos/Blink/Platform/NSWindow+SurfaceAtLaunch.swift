import AppKit

extension NSUserInterfaceItemIdentifier {
    /// Tags Blink's launch-time setup windows (onboarding, detection-mode
    /// choice / permission flow, stale-grant recovery) so the Dock-reopen
    /// handler in AppDelegate can re-front them when buried.
    static let blinkSetupWindow = NSUserInterfaceItemIdentifier("BlinkSetupWindow")
}

/// Window delegate for Blink's setup windows. Runs a caller-supplied closure
/// when the user closes the window (red button / Cmd-W / performClose). The
/// behavior is per-window: the detection-mode / permission / recovery windows
/// default to Simple mode + a confirming HUD; the onboarding window (shown
/// before any mode is even presented) quits.
///
/// `windowShouldClose(_:)` only fires for USER-initiated closes — the flows
/// resolve programmatically via `orderOut()`, which never routes through this
/// delegate, so picking Smart/Simple does NOT trigger `onClose`. Returns false
/// because the closure handles teardown itself (orderOut, or terminate).
///
/// The owning controller must retain its delegate instance — `NSWindow.delegate`
/// is a weak reference.
final class SetupWindowCloseDelegate: NSObject, NSWindowDelegate {
    private let onClose: () -> Void
    init(onClose: @escaping () -> Void) { self.onClose = onClose }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        onClose()
        return false
    }
}

extension NSWindow {
    /// Creates a closable titled setup window matching the About-window chrome
    /// the user asked for: a real titlebar with functional traffic lights + a
    /// Dock icon + native window management (drag, Cmd-Tab, Mission Control),
    /// so the window is never lost behind other apps and the user always knows
    /// it's there.
    ///
    /// **Closable** — the close button is live; the owning controller assigns
    /// a `SetupWindowCloseDelegate` to decide what closing does (default to
    /// Simple mode, or quit for onboarding).
    ///
    /// **Standard (not full-size-content) titlebar** — deliberately NOT
    /// `.fullSizeContentView` + transparent titlebar. That combination put the
    /// SwiftUI hosting view in a safe-area/frame oscillation that flooded the
    /// main run loop with ~800 window-update notifications/sec, which in turn
    /// blocked the window from ever painting to the front. A plain titlebar
    /// (exactly what the About window uses) is storm-free and reliably
    /// foregrounds.
    static func makeSetupWindow(contentRect: NSRect, title: String) -> NSWindow {
        let win = NSWindow(
            contentRect: contentRect,
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        win.title = title
        win.isReleasedWhenClosed = false
        win.identifier = .blinkSetupWindow
        return win
    }
    /// Reliably brings a launch-time modal-style window (onboarding,
    /// detection-mode choice, permission flow, stale-grant recovery) to the
    /// front — even when another app is frontmost — WITHOUT leaving it as a
    /// permanently-floating "always on top" window.
    ///
    /// **Why this exists.** `NSApp.activate(ignoringOtherApps: true)` is
    /// deprecated as of macOS 14, and Sonoma+ routinely ignores its
    /// focus-steal override. The result: Blink's borderless setup windows
    /// opened *behind* whatever app the user was in, with no titlebar to find
    /// them by. The naive fix (permanent `.floating` level) trades one
    /// annoyance for another — a window that hovers above all the user's work.
    ///
    /// **What this does instead.** A *one-shot* elevation: jump to `.floating`
    /// just long enough to win the launch focus race, then drop back to the
    /// resting level (`.normal`) so the window behaves like any other once the
    /// user starts interacting. Paired with the Dock-reopen handler in
    /// AppDelegate, a buried window is always recoverable by clicking the Dock
    /// icon — so the user always knows it's there.
    ///
    /// Safe for the permission flow specifically: the resting level is
    /// `.normal`, restored after 0.6s — well before the user taps "Grant
    /// Access", which is what spawns the system TCC dialog. A floating Blink
    /// window must never sit above that OS dialog.
    func surfaceAtLaunch() {
        // Follow the user to whatever Space they're currently on, so the
        // window never opens on a different Space and appears "missing".
        collectionBehavior.insert(.moveToActiveSpace)

        let restingLevel = level
        level = .floating
        makeKeyAndOrderFront(nil)
        orderFrontRegardless()
        NSApp.activate()

        // Drop back to the resting level once the window is on screen. 0.6s is
        // long enough to win the launch race, short enough that it's a normal
        // window by the time the user could switch apps or trigger a TCC
        // dialog.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            self?.level = restingLevel
        }
    }
}
