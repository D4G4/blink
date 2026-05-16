import SwiftUI
import AppKit

/// Shows a window explaining why mic detection is pausing Blink, with options to resolve.
@MainActor
final class MicWarningWindowController {
    static let shared = MicWarningWindowController()
    private var window: NSWindow?
    private var closeDelegate: MicWindowCloseDelegate?

    func show(appState: AppState) {
        if let existing = window, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let view = MicWarningView(onDismiss: { [weak self] in
            self?.dismiss()
        }, onDisable: { [weak self] in
            UserDefaults.standard.set(false, forKey: "pauseDuringCalls")
            appState.micAlwaysOnWarning = false
            self?.dismiss()
        })

        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 420),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        win.title = "Microphone Detected"
        win.isReleasedWhenClosed = false
        win.center()
        win.contentView = NSHostingView(rootView: view)

        NSApp.setActivationPolicy(.regular)
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        UIActionLogger.windowOpened("MicWarning")

        closeDelegate = MicWindowCloseDelegate { [weak self] in
            UIActionLogger.windowClosed("MicWarning")
            DispatchQueue.main.async {
                self?.window = nil
                self?.closeDelegate = nil
                NSApp.setActivationPolicy(.accessory)
            }
        }
        win.delegate = closeDelegate

        self.window = win
    }

    private func dismiss() {
        window?.close()
        window = nil
        closeDelegate = nil
        NSApp.setActivationPolicy(.accessory)
    }
}

private struct MicWarningView: View {
    let onDismiss: () -> Void
    let onDisable: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "mic.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.orange)

            Text("Your Microphone Is Always On")
                .font(.system(size: 20, weight: .bold, design: .rounded))

            VStack(alignment: .leading, spacing: 12) {
                explanationRow(
                    icon: "waveform",
                    text: "Blink detected your mic is active during the startup. This usually means Dictation, Siri, or Voice Control is enabled."
                )
                explanationRow(
                    icon: "pause.circle",
                    text: "Blink pauses your break timer when the mic is on, so you're not interrupted during calls. But if the mic is always on, your timer will never run."
                )
                explanationRow(
                    icon: "gear",
                    text: "You have two options: turn off Dictation in System Settings → Keyboard, or disable Blink's mic detection below."
                )
            }
            .padding(.horizontal, 8)

            Spacer()

            VStack(spacing: 10) {
                Button {
                    onDisable()
                } label: {
                    Text("Turn off Blink's mic detection")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .background(.orange)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)

                Text("Breaks will show even during calls")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(24)
        .frame(width: 480, height: 420)
    }

    private func explanationRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(.orange)
                .frame(width: 20)
            Text(text)
                .font(.system(size: 13))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private class MicWindowCloseDelegate: NSObject, NSWindowDelegate {
    let onClose: () -> Void
    init(_ onClose: @escaping () -> Void) { self.onClose = onClose }
    func windowWillClose(_ notification: Notification) { onClose() }
}
