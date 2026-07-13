import SwiftUI
import AppKit

/// Small window for the pause menu's "Custom…" option — pick an arbitrary
/// hours/minutes duration, then pause for exactly that long (a `.timed` pause,
/// so it auto-resumes on its own like the 1h / 6h / until-tomorrow presets).
@MainActor
final class CustomPauseWindowController {
    static let shared = CustomPauseWindowController()
    private var window: NSWindow?
    private var closeDelegate: CustomPauseCloseDelegate?

    func show(appState: AppState, theme: BlinkTheme) {
        if let existing = window, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let view = CustomPauseView(
            theme: theme,
            onCancel: { [weak self] in self?.dismiss() },
            onPause: { [weak self] seconds in
                UIActionLogger.buttonTapped("Pause custom (\(Int(seconds))s)", context: "CustomPause")
                appState.pause(.forDuration(seconds))
                self?.dismiss()
            }
        )

        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 260),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        win.title = "Pause Blink"
        win.isReleasedWhenClosed = false
        win.center()
        win.contentView = NSHostingView(rootView: view)

        NSApp.setActivationPolicy(.regular)
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        UIActionLogger.windowOpened("CustomPause")

        closeDelegate = CustomPauseCloseDelegate { [weak self] in
            UIActionLogger.windowClosed("CustomPause")
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

struct CustomPauseView: View {
    let theme: BlinkTheme
    let onCancel: () -> Void
    let onPause: (TimeInterval) -> Void
    @Environment(\.colorScheme) private var colorScheme

    @State private var hours: Int = 0
    @State private var minutes: Int = 30

    private var totalSeconds: TimeInterval { TimeInterval(hours * 3600 + minutes * 60) }
    private var accent: Color { theme.accent(for: colorScheme) }

    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 4) {
                Image(systemName: "pause.circle.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(accent)
                Text("Pause for a custom time")
                    .font(.system(size: 16, weight: .semibold))
                Text("Blink resumes automatically when it's up.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 20) {
                stepper(value: $hours, range: 0...12, step: 1, unit: "hr")
                stepper(value: $minutes, range: 0...59, step: 5, unit: "min")
            }

            HStack(spacing: 10) {
                Button(action: onCancel) {
                    Text("Cancel")
                        .font(.system(size: 13, weight: .medium))
                        .frame(maxWidth: .infinity)
                        .frame(height: 34)
                        .background(Color.primary.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)

                Button {
                    onPause(totalSeconds)
                } label: {
                    Text("Pause")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(theme.textOnAccent(for: colorScheme))
                        .frame(maxWidth: .infinity)
                        .frame(height: 34)
                        .background(totalSeconds > 0 ? accent : Color.gray.opacity(0.4))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .disabled(totalSeconds <= 0)
            }
        }
        .padding(24)
        .frame(width: 360, height: 260)
    }

    /// Themed −/＋ stepper. Custom buttons rather than SwiftUI `Stepper` so it
    /// renders on-brand and captures correctly in snapshots (native steppers
    /// render as placeholder glyphs under ImageRenderer).
    private func stepper(value: Binding<Int>, range: ClosedRange<Int>, step: Int, unit: String) -> some View {
        HStack(spacing: 8) {
            stepButton("minus", enabled: value.wrappedValue > range.lowerBound) {
                value.wrappedValue = max(range.lowerBound, value.wrappedValue - step)
            }
            Text("\(value.wrappedValue) \(unit)")
                .font(.system(size: 15, weight: .medium, design: .monospaced))
                .frame(width: 62, alignment: .center)
            stepButton("plus", enabled: value.wrappedValue < range.upperBound) {
                value.wrappedValue = min(range.upperBound, value.wrappedValue + step)
            }
        }
    }

    private func stepButton(_ symbol: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(enabled ? accent : Color.secondary.opacity(0.4))
                .frame(width: 28, height: 28)
                .background(Color.primary.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 7))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}

private class CustomPauseCloseDelegate: NSObject, NSWindowDelegate {
    let onClose: () -> Void
    init(_ onClose: @escaping () -> Void) { self.onClose = onClose }
    func windowWillClose(_ notification: Notification) { onClose() }
}
