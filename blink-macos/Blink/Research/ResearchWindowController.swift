import SwiftUI
import AppKit

/// Opens the research summary in a standalone window.
final class ResearchWindowController {
    static let shared = ResearchWindowController()
    private var window: NSWindow?
    private var closeDelegate: WindowCloseDelegate?

    func show(theme: BlinkTheme) {
        if let existing = window, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let view = ResearchView(theme: theme, onDismiss: { [weak self] in
            self?.dismiss()
        })

        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 700),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        win.title = "Research"
        win.center()
        win.contentView = NSHostingView(rootView: view)
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        closeDelegate = WindowCloseDelegate { [weak self] in
            DispatchQueue.main.async {
                self?.window = nil
                self?.closeDelegate = nil
            }
        }
        win.delegate = closeDelegate

        self.window = win
    }

    private func dismiss() {
        window?.close()
        window = nil
        closeDelegate = nil
    }
}

private class WindowCloseDelegate: NSObject, NSWindowDelegate {
    let onClose: () -> Void
    init(_ onClose: @escaping () -> Void) { self.onClose = onClose }
    func windowWillClose(_ notification: Notification) { onClose() }
}
