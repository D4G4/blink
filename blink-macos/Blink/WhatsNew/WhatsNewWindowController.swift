import SwiftUI
import AppKit

/// Centered modal-ish window that surfaces `WhatsNewManifest.items` on
/// the first launch after a version upgrade. One-shot per release.
@MainActor
final class WhatsNewWindowController {
    private var window: NSWindow?

    /// Open the window with the given items. Caller is responsible for
    /// deciding whether to show — typically via
    /// `WhatsNewManifest.itemsToShowOnLaunch()`.
    func show(
        theme: BlinkTheme,
        version: String,
        items: [WhatsNewItem],
        onOpenAction: @escaping (WhatsNewItem.OpenAction) -> Void
    ) {
        guard window == nil else { return }

        let width: CGFloat = 520
        let height: CGFloat = 460

        let view = WhatsNewView(
            theme: theme,
            version: version,
            items: items,
            onDismiss: { [weak self] in self?.close() },
            onOpenAction: { [weak self] action in
                self?.close()
                onOpenAction(action)
            }
        )

        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: width, height: height),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        win.title = "What's New"
        win.isReleasedWhenClosed = false
        win.level = .floating
        win.contentView = NSHostingView(rootView: view)
        win.center()

        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        win.makeKeyAndOrderFront(nil)
        UIActionLogger.windowOpened("WhatsNew")

        self.window = win
    }

    func close() {
        guard let win = window else { return }
        window = nil
        win.orderOut(nil)
        // Return to accessory mode — the app is a menu bar utility, the
        // What's New window was a temporary modal surface.
        NSApp.setActivationPolicy(.accessory)
    }
}
