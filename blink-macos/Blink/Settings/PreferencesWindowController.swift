import SwiftUI
import AppKit

/// Custom preferences window — not tied to macOS Settings scene.
final class PreferencesWindowController {
    static let shared = PreferencesWindowController()

    private var window: NSWindow?
    private var closeObserver: NSObjectProtocol?

    func show(appState: AppState, themeManager: ThemeManager) {
        // If window exists, just bring it to front
        if let win = window, win.isVisible {
            win.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let prefsView = SettingsView(appState: appState)
            .environmentObject(themeManager)

        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 380),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        win.title = "Blink Preferences"
        win.contentView = NSHostingView(rootView: prefsView)
        win.center()
        win.isReleasedWhenClosed = false

        // Bring to front
        NSApp.setActivationPolicy(.regular)
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        // Go back to accessory when window closes
        if let existing = closeObserver {
            NotificationCenter.default.removeObserver(existing)
        }
        closeObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: win,
            queue: .main
        ) { [weak self] _ in
            self?.window = nil
            NSApp.setActivationPolicy(.accessory)
        }

        self.window = win
    }
}
