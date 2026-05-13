import SwiftUI
import AppKit

/// Shows FlowLearnMoreView in a standalone window — used from Settings.
final class FlowLearnMoreWindowController {
    static let shared = FlowLearnMoreWindowController()
    private var window: NSWindow?

    func show(theme: BlinkTheme) {
        if let existing = window {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let view = FlowLearnMoreView(theme: theme, onDismiss: { [weak self] in
            self?.dismiss()
        })

        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 560),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        win.title = "Flow Detection"
        win.center()
        win.contentView = NSHostingView(rootView: view)
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        win.delegate = WindowCloseDelegate { [weak self] in
            self?.window = nil
        }

        self.window = win
    }

    private func dismiss() {
        window?.close()
        window = nil
    }
}

/// Simple delegate to clear the window reference on close.
private class WindowCloseDelegate: NSObject, NSWindowDelegate {
    let onClose: () -> Void
    init(_ onClose: @escaping () -> Void) { self.onClose = onClose }
    func windowWillClose(_ notification: Notification) { onClose() }
}
