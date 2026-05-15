import SwiftUI
import AppKit

/// Shows FlowLearnMoreView in a standalone window — used from Settings.
final class FlowLearnMoreWindowController {
    static let shared = FlowLearnMoreWindowController()
    private var window: NSWindow?
    private var closeDelegate: WindowCloseDelegate?  // strong reference to prevent deallocation

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
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 700),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        win.title = "Flow Detection"
        win.isReleasedWhenClosed = false
        win.center()
        win.contentView = NSHostingView(rootView: view)
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        UIActionLogger.windowOpened("FlowLearnMore")

        closeDelegate = WindowCloseDelegate { [weak self] in
            UIActionLogger.windowClosed("FlowLearnMore")
            // Defer cleanup to avoid deallocating the delegate while inside its own callback
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
