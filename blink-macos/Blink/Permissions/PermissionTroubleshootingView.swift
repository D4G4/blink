import SwiftUI

/// Shown when Input Monitoring permission is reported as granted but the
/// real `CGEventTap` still won't start. Typical cause: the TCC grant is
/// tied to an earlier binary CDHash (common across Homebrew updates and
/// Xcode rebuilds of ad-hoc signed apps) and the new binary needs the
/// permission toggled off and back on to inherit the grant.
struct PermissionTroubleshootingView: View {
    let theme: BlinkTheme
    let onOpenSettings: () -> Void
    let onTryAgain: () -> Void
    @Environment(\.colorScheme) private var colorScheme

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

            VStack(spacing: 0) {
                // Header: warning icon + title
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

                // Explanation
                Text("This usually means the permission was granted to an earlier version of Blink. macOS ties permissions to the exact app binary — when Blink updates, you need to toggle the permission off and back on so the new version inherits it.")
                    .font(.system(size: 12))
                    .foregroundStyle(fg.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 36)
                    .padding(.bottom, 18)

                // Steps
                VStack(alignment: .leading, spacing: 10) {
                    stepRow(num: 1, text: "Click \"Open Settings\" below", fg: fg, bgTop: bgTop)
                    stepRow(num: 2, text: "Toggle Blink off, then back on", fg: fg, bgTop: bgTop)
                    stepRow(num: 3, text: "Come back and click \"Try Again\"", fg: fg, bgTop: bgTop)
                }
                .padding(.horizontal, 60)

                Spacer()

                // Buttons
                HStack(spacing: 12) {
                    Button {
                        onOpenSettings()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "gear")
                                .font(.system(size: 12, weight: .semibold))
                            Text("Open Settings")
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

                    Button {
                        onTryAgain()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 12, weight: .semibold))
                            Text("Try Again")
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
                .padding(.bottom, 28)
            }
        }
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
