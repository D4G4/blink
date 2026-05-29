import SwiftUI
import AppKit

/// Opens the "Where's the Blink icon?" help dialog as a standalone window.
/// Shown from the launch HUD's "Can't find it" button.
@MainActor
final class MenuBarHelpWindowController {
    static let shared = MenuBarHelpWindowController()

    private var window: NSWindow?
    private var closeObserver: NSObjectProtocol?

    /// `onOpenPreferences` is the guaranteed fallback entry point — even if
    /// the user never recovers the menu bar icon, this keeps Blink reachable.
    func show(onOpenPreferences: @escaping () -> Void) {
        if let win = window, win.isVisible {
            win.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let theme = ThemeManager.shared.current

        let view = MenuBarHelpView(
            theme: theme,
            onOpenPreferences: { onOpenPreferences() },
            onDismiss: { [weak self] in self?.dismiss() }
        )

        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 540, height: 620),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        win.title = "Find Blink"
        win.contentView = NSHostingView(rootView: view)
        win.center()
        win.isReleasedWhenClosed = false

        NSApp.setActivationPolicy(.regular)
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        UIActionLogger.windowOpened("MenuBarHelp")

        if let existing = closeObserver {
            NotificationCenter.default.removeObserver(existing)
        }
        closeObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: win,
            queue: .main
        ) { [weak self] _ in
            UIActionLogger.windowClosed("MenuBarHelp")
            self?.window = nil
            NSApp.setActivationPolicy(.accessory)
        }

        self.window = win
    }

    private func dismiss() {
        window?.close()
        window = nil
        NSApp.setActivationPolicy(.accessory)
    }
}
