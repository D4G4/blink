import SwiftUI

/// Visual step-by-step guide for granting Accessibility permission manually.
/// Used in sandboxed (App Store) builds where the system prompt can't auto-appear.
/// Auto-dismissed by AppState polling when permission is granted.
struct PermissionGuideView: View {
    let theme: BlinkTheme
    let onOpenSettings: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let fg = theme.onBackgroundText(for: colorScheme)
        let accent = theme.accent(for: colorScheme)

        ZStack {
            theme.backgroundGradient(for: colorScheme)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Header
                Image(systemName: "hand.raised.circle.fill")
                    .font(.system(size: 48, weight: .light))
                    .foregroundStyle(.white)
                    .padding(.bottom, 16)

                Text("Grant Accessibility Access")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(fg)
                    .padding(.bottom, 6)

                Text("Blink needs this to detect your typing and mouse patterns")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(fg.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 28)

                // Steps
                VStack(spacing: 0) {
                    stepRow(
                        icon: "gear",
                        title: "Open Accessibility Settings",
                        subtitle: "Click the button below to open the right page",
                        fg: fg
                    )
                    stepConnector()
                    stepRow(
                        icon: "plus.circle.fill",
                        title: "Click the  +  button",
                        subtitle: "At the bottom-left of the app list",
                        fg: fg
                    )
                    stepConnector()
                    stepRow(
                        icon: "folder.fill",
                        title: "Find Blink in Applications",
                        subtitle: "Applications → Blink → Open",
                        fg: fg
                    )
                    stepConnector()
                    stepRow(
                        icon: "switch.2",
                        title: "Toggle Blink on",
                        subtitle: "You may need to enter your password",
                        fg: fg
                    )
                }
                .padding(20)
                .background(.white.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .frame(maxWidth: 400)

                Spacer()

                // Privacy note
                HStack(spacing: 8) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.8))
                    Text("Blink reads input timing only — never what you type or see")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(fg.opacity(0.7))
                }
                .padding(.bottom, 16)

                // Open Settings button
                Button {
                    onOpenSettings()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "gear")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Open Accessibility Settings")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundStyle(accent)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(.white)
                    .clipShape(Capsule())
                    .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
                }
                .buttonStyle(.plain)
                .frame(maxWidth: 320)

                Text("This screen will close automatically once access is granted")
                    .font(.system(size: 11))
                    .foregroundStyle(fg.opacity(0.5))
                    .padding(.top, 10)
                    .padding(.bottom, 32)
            }
            .padding(.horizontal, 40)
        }
    }

    // MARK: - Step Components

    private func stepRow(icon: String, title: String, subtitle: String, fg: Color) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(fg.opacity(0.75))
            }

            Spacer()
        }
        .padding(.vertical, 8)
    }

    private func stepConnector() -> some View {
        HStack {
            Rectangle()
                .fill(.white.opacity(0.3))
                .frame(width: 2, height: 16)
                .padding(.leading, 15)
            Spacer()
        }
    }
}

#Preview("Permission Guide — Peach") {
    PermissionGuideView(theme: .peach, onOpenSettings: {})
        .frame(width: 500, height: 650)
}

#Preview("Permission Guide — Midnight Dark") {
    PermissionGuideView(theme: .midnight, onOpenSettings: {})
        .frame(width: 500, height: 650)
        .preferredColorScheme(.dark)
}

#Preview("Permission Guide — Sage") {
    PermissionGuideView(theme: .sage, onOpenSettings: {})
        .frame(width: 500, height: 650)
}
