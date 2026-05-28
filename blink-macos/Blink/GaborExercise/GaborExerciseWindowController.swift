import SwiftUI
import AppKit

/// Opens the Gabor exercise in a native fullscreen window (hides menu bar and dock).
final class GaborExerciseWindowController: NSObject, NSWindowDelegate {
    static let shared = GaborExerciseWindowController()
    private var window: NSWindow?
    private var exerciseState: GaborExerciseState?
    private var keyMonitor: Any?

    func show(theme: BlinkTheme) {
        if let existing = window, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let state = GaborExerciseState()
        self.exerciseState = state

        let view = GaborExerciseView(
            state: state,
            theme: theme,
            onDismiss: { [weak self] in self?.dismiss() }
        )

        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 700),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        win.title = "Eye Exercise"
        win.isReleasedWhenClosed = false
        win.titlebarAppearsTransparent = true
        win.titleVisibility = .hidden
        win.styleMask.insert(.fullSizeContentView)
        win.backgroundColor = .black
        win.center()
        win.contentView = NSHostingView(rootView: view)
        win.delegate = self
        win.collectionBehavior = [.fullScreenPrimary]

        NSApp.setActivationPolicy(.regular)
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        UIActionLogger.windowOpened("GaborExercise")

        self.window = win

        // Intercept Esc at the event level. During a trial or the
        // instructions, it steps back to the picker and is consumed so it
        // doesn't trigger macOS's exit-fullscreen (which would tear the
        // whole exercise down). From the picker/results, Esc falls through
        // to the default behavior (exit fullscreen → close the exercise).
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.keyCode == 53, let state = self?.exerciseState else { return event }
            switch state.phase {
            case .presenting, .feedback, .instructions:
                state.returnToPicker()
                return nil
            default:
                return event
            }
        }

        // Enter native fullscreen after a brief delay so the window is on screen
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            win.toggleFullScreen(nil)
        }
    }

    private func dismiss() {
        exerciseState?.cancelSession()
        guard let win = window else { return }

        if win.styleMask.contains(.fullScreen) {
            // Exit fullscreen first, then close in the delegate callback
            win.toggleFullScreen(nil)
        } else {
            cleanup(win)
        }
    }

    private func cleanup(_ win: NSWindow) {
        removeKeyMonitor()
        win.close()
        window = nil
        exerciseState = nil
        NSApp.setActivationPolicy(.accessory)
        UIActionLogger.windowClosed("GaborExercise")
    }

    private func removeKeyMonitor() {
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
    }

    // MARK: - NSWindowDelegate

    func windowDidExitFullScreen(_ notification: Notification) {
        // If dismiss() triggered the exit, close the window now
        if let win = window {
            cleanup(win)
        }
    }

    func windowWillClose(_ notification: Notification) {
        removeKeyMonitor()
        exerciseState?.cancelSession()
        window = nil
        exerciseState = nil
        NSApp.setActivationPolicy(.accessory)
        UIActionLogger.windowClosed("GaborExercise")
    }
}
