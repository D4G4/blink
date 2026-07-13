import SwiftUI
import AppKit

/// The "Pause Blink" picker window — presets (1h / 6h / until tomorrow /
/// while the current app is open / indefinitely) plus a custom hours/minutes
/// duration, in one themed surface. Replaces the old native pause dropdown so
/// every option shares the same look. Clicking any option pauses and closes.
@MainActor
final class PausePickerWindowController {
    static let shared = PausePickerWindowController()
    private var window: NSWindow?
    private var closeDelegate: PausePickerCloseDelegate?

    func show(appState: AppState, theme: BlinkTheme) {
        if let existing = window, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let view = PausePickerView(
            theme: theme,
            appName: appState.lastActiveAppName,
            appBundleID: appState.lastActiveAppID,
            onPreset: { [weak self] mode in
                UIActionLogger.buttonTapped("Pause \(mode.logDescription)", context: "PausePicker")
                appState.pause(mode)
                self?.dismiss()
            },
            onCancel: { [weak self] in self?.dismiss() }
        )

        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 480),
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
        UIActionLogger.windowOpened("PausePicker")

        closeDelegate = PausePickerCloseDelegate { [weak self] in
            UIActionLogger.windowClosed("PausePicker")
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

struct PausePickerView: View {
    let theme: BlinkTheme
    /// Frontmost non-Blink app for the "While <app> is open" preset; nil hides it.
    let appName: String?
    let appBundleID: String?
    let onPreset: (PauseMode) -> Void
    let onCancel: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    @State private var hours: Int = 0
    @State private var minutes: Int = 30

    private var totalSeconds: TimeInterval { TimeInterval(hours * 3600 + minutes * 60) }
    private var accent: Color { theme.accent(for: colorScheme) }

    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 4) {
                Image(systemName: "pause.circle.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(accent)
                Text("Pause Blink")
                    .font(.system(size: 16, weight: .semibold))
                Text("Resumes automatically when it's up.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    presetButton("1 hour") { onPreset(.forDuration(3600)) }
                    presetButton("6 hours") { onPreset(.forDuration(6 * 3600)) }
                }
                presetButton("Until tomorrow") { onPreset(.untilTomorrow()) }
                if let name = appName, let id = appBundleID {
                    presetButton("While \(name) is open") {
                        onPreset(.currentApp(bundleID: id, name: name))
                    }
                }
                presetButton("Indefinitely", muted: true) { onPreset(.indefinite) }
            }

            HStack(spacing: 8) {
                dividerLine
                Text("Custom")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                dividerLine
            }

            HStack(spacing: 16) {
                stepper(value: $hours, range: 0...12, step: 1, unit: "hr")
                stepper(value: $minutes, range: 0...59, step: 5, unit: "min")
            }

            Button {
                onPreset(.forDuration(totalSeconds))
            } label: {
                Text("Pause for \(hours)h \(minutes)m")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(theme.textOnAccent(for: colorScheme))
                    .frame(maxWidth: .infinity)
                    .frame(height: 36)
                    .background(totalSeconds > 0 ? accent : Color.gray.opacity(0.4))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
            .disabled(totalSeconds <= 0)

            Spacer(minLength: 0)

            Button(action: onCancel) {
                Text("Cancel")
                    .font(.system(size: 13, weight: .medium))
                    .frame(maxWidth: .infinity)
                    .frame(height: 34)
                    .background(Color.primary.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
        }
        .padding(24)
        .frame(width: 380, height: 480)
    }

    private var dividerLine: some View {
        Rectangle().fill(Color.primary.opacity(0.1)).frame(height: 1)
    }

    /// A themed preset row. `muted` distinguishes "Indefinitely" (no auto-resume).
    private func presetButton(_ label: String, muted: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(muted ? Color.secondary : accent)
                .frame(maxWidth: .infinity)
                .frame(height: 36)
                .background((muted ? Color.primary : accent).opacity(muted ? 0.06 : 0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    /// Themed −/＋ stepper — custom buttons render on-brand and capture
    /// correctly in snapshots (native `Stepper` renders as placeholder glyphs).
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

private class PausePickerCloseDelegate: NSObject, NSWindowDelegate {
    let onClose: () -> Void
    init(_ onClose: @escaping () -> Void) { self.onClose = onClose }
    func windowWillClose(_ notification: Notification) { onClose() }
}
