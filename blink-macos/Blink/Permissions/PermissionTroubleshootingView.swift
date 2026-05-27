import SwiftUI
import AppKit

/// Shown when Input Monitoring permission is reported as granted but the
/// real `CGEventTap` still won't start. Typical cause: the TCC grant is
/// tied to an earlier binary CDHash (common across Homebrew updates and
/// Xcode rebuilds of ad-hoc signed apps) and the new binary needs the
/// permission toggled off and back on to inherit the grant.
///
/// After `maxAttemptsBeforeFallback` failed Try Again clicks, the view
/// swaps to a final-fallback body with a Terminal command (`tccutil
/// reset`) and a Quit button — escape valve so users with corrupted TCC
/// state aren't stuck in an infinite retry loop.
struct PermissionTroubleshootingView: View {
    let theme: BlinkTheme
    let onOpenSettings: () -> Void
    let onTryAgain: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    @State private var attempts: Int = 0

    private static let maxAttemptsBeforeFallback = 3

    var body: some View {
        let fg = theme.onBackgroundText(for: colorScheme)
        let bgTop = theme.backgroundTop(for: colorScheme)

        ZStack {
            theme.backgroundGradient(for: colorScheme)
                .ignoresSafeArea()

            RadialGradient(
                colors: [fg.opacity(0.1), .clear],
                center: .top,
                startRadius: 50,
                endRadius: 400
            )

            if attempts < Self.maxAttemptsBeforeFallback {
                standardBody(fg: fg, bgTop: bgTop)
            } else {
                fallbackBody(fg: fg, bgTop: bgTop)
            }
        }
    }

    // MARK: - Standard body (first 3 Try Again attempts)

    private func standardBody(fg: Color, bgTop: Color) -> some View {
        VStack(spacing: 0) {
            VStack(spacing: 4) {
                HStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 22, weight: .light))
                        .foregroundStyle(fg)
                    Text("Permission Granted — But Not Working")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(fg)
                }
                Text("Blink has Input Monitoring permission, but can't read events")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(fg)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 20)
            .padding(.bottom, 14)

            Text("This usually means the permission was granted to an earlier version of Blink. macOS ties permissions to the exact app binary — when Blink updates, you need to toggle the permission off and back on so the new version inherits it.")
                .font(.system(size: 12))
                .foregroundStyle(fg.opacity(0.9))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 36)
                .padding(.bottom, 18)

            VStack(alignment: .leading, spacing: 10) {
                stepRow(num: 1, text: "Click \"Open Settings\" below", fg: fg, bgTop: bgTop)
                stepRow(num: 2, text: "Toggle Blink off, then back on", fg: fg, bgTop: bgTop)
                stepRow(num: 3, text: "Come back and click \"Try Again\"", fg: fg, bgTop: bgTop)
            }
            .padding(.horizontal, 60)

            Spacer()

            HStack(spacing: 12) {
                primaryButton(label: "Open Settings", icon: "gear", fg: fg, bgTop: bgTop) {
                    onOpenSettings()
                }
                secondaryButton(label: "Try Again", icon: "arrow.clockwise", fg: fg) {
                    attempts += 1
                    onTryAgain()
                }
            }
            .padding(.bottom, 28)
        }
    }

    // MARK: - Fallback body (after maxAttemptsBeforeFallback)

    private func fallbackBody(fg: Color, bgTop: Color) -> some View {
        VStack(spacing: 0) {
            VStack(spacing: 4) {
                HStack(spacing: 10) {
                    Image(systemName: "wrench.and.screwdriver.fill")
                        .font(.system(size: 22, weight: .light))
                        .foregroundStyle(fg)
                    Text("Still Not Working — Reset the Permission")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(fg)
                }
                Text("macOS's permission cache for Blink may be in a bad state")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(fg)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 20)
            .padding(.bottom, 14)

            Text("Open Terminal and paste this command. It clears Blink's Input Monitoring entry from macOS's privacy database. Then quit Blink and re-launch — you'll be asked to grant the permission fresh.")
                .font(.system(size: 12))
                .foregroundStyle(fg.opacity(0.9))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 36)
                .padding(.bottom, 14)

            // Terminal command — monospace, selectable, with copy button
            terminalCommand(fg: fg, bgTop: bgTop)
                .padding(.horizontal, 36)
                .padding(.bottom, 16)

            Spacer()

            HStack(spacing: 12) {
                primaryButton(label: "Quit Blink", icon: "power", fg: fg, bgTop: bgTop) {
                    NSApp.terminate(nil)
                }
                secondaryButton(label: "Try Again", icon: "arrow.clockwise", fg: fg) {
                    onTryAgain()
                }
            }
            .padding(.bottom, 28)
        }
    }

    // MARK: - Reusable bits

    private func terminalCommand(fg: Color, bgTop: Color) -> some View {
        let command = "sudo tccutil reset ListenEvent com.blink20.app"
        return HStack(spacing: 8) {
            Text(command)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(fg)
                .textSelection(.enabled)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Spacer(minLength: 8)
            Button {
                let pb = NSPasteboard.general
                pb.clearContents()
                pb.setString(command, forType: .string)
            } label: {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(fg)
                    .frame(width: 28, height: 28)
                    .background(fg.opacity(0.18))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
            .help("Copy to clipboard")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(fg.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func primaryButton(label: String, icon: String, fg: Color, bgTop: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                Text(label)
                    .font(.system(size: 14, weight: .bold))
            }
            .foregroundStyle(bgTop)
            .frame(height: 40)
            .padding(.horizontal, 20)
            .background(fg)
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.2), radius: 10, y: 5)
        }
        .buttonStyle(.plain)
    }

    private func secondaryButton(label: String, icon: String, fg: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                Text(label)
                    .font(.system(size: 14, weight: .bold))
            }
            .foregroundStyle(fg)
            .frame(height: 40)
            .padding(.horizontal, 20)
            .background(fg.opacity(0.25))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func stepRow(num: Int, text: String, fg: Color, bgTop: Color) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(fg)
                    .frame(width: 22, height: 22)
                Text("\(num)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(bgTop)
            }
            Text(text)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(fg)
        }
    }
}

#Preview("Troubleshooting — Peach") {
    PermissionTroubleshootingView(theme: .peach, onOpenSettings: {}, onTryAgain: {})
        .frame(width: 700, height: 420)
}

#Preview("Troubleshooting — Midnight") {
    PermissionTroubleshootingView(theme: .midnight, onOpenSettings: {}, onTryAgain: {})
        .frame(width: 700, height: 420)
        .preferredColorScheme(.dark)
}

#Preview("Troubleshooting — Sage") {
    PermissionTroubleshootingView(theme: .sage, onOpenSettings: {}, onTryAgain: {})
        .frame(width: 700, height: 420)
}
