import SwiftUI
import AppKit

/// Opens the "Why do I exist?" dialog as a standalone window from the menu bar.
final class WhyExistWindowController {
    static let shared = WhyExistWindowController()

    private var window: NSWindow?
    private var closeObserver: NSObjectProtocol?

    func show() {
        if let win = window, win.isVisible {
            win.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let theme = ThemeManager.shared.current

        let view = ZStack {
            WhyExistView(theme: theme, onDismiss: { [weak self] in
                self?.dismiss()
            })
        }
        .frame(width: 620, height: 560)
        .background(Color(nsColor: .windowBackgroundColor))

        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 620, height: 560),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        win.title = "About Blink"
        win.contentView = NSHostingView(rootView: view)
        win.center()
        win.isReleasedWhenClosed = false

        NSApp.setActivationPolicy(.regular)
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        if let existing = closeObserver {
            NotificationCenter.default.removeObserver(existing)
        }
        closeObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: win,
            queue: .main
        ) { _ in
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
