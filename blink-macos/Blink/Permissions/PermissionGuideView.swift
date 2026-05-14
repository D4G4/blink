import SwiftUI

/// Visual step-by-step guide for granting Accessibility permission manually.
/// Auto-dismissed by AppState polling when permission is granted.
struct PermissionGuideView: View {
    let theme: BlinkTheme
    let onOpenSettings: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let fg = theme.onBackgroundText(for: colorScheme)
        let accent = theme.accent(for: colorScheme)
        let bgTop = theme.backgroundTop(for: colorScheme)

        ZStack {
            theme.backgroundGradient(for: colorScheme)
                .ignoresSafeArea()

            // Subtle radial glow
            RadialGradient(
                colors: [.white.opacity(0.12), .clear],
                center: .center,
                startRadius: 50,
                endRadius: 350
            )

            VStack(spacing: 0) {
                Spacer()

                // Header icon
                ZStack {
                    Circle()
                        .fill(.white.opacity(0.2))
                        .frame(width: 80, height: 80)
                    Image(systemName: "hand.raised.circle.fill")
                        .font(.system(size: 44, weight: .light))
                        .foregroundStyle(.white)
                }
                .padding(.bottom, 20)

                Text("Grant Accessibility Access")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.bottom, 8)

                Text("Blink needs this to detect your typing and mouse patterns")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 32)

                // Steps card
                VStack(spacing: 0) {
                    stepRow(
                        icon: "gear",
                        title: "Open Accessibility Settings",
                        subtitle: "Click the button below to open the right page",
                        bgTop: bgTop
                    )
                    stepConnector()
                    stepRow(
                        icon: "plus.circle.fill",
                        title: "Click the  +  button",
                        subtitle: "At the bottom-left of the app list",
                        bgTop: bgTop
                    )
                    stepConnector()
                    stepRow(
                        icon: "folder.fill",
                        title: "Find Blink in Applications",
                        subtitle: "Applications → Blink → Open",
                        bgTop: bgTop
                    )
                    stepConnector()
                    stepRow(
                        icon: "switch.2",
                        title: "Toggle Blink on",
                        subtitle: "You may need to enter your password",
                        bgTop: bgTop
                    )
                }
                .padding(24)
                .background(.white.opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(.white.opacity(0.15), lineWidth: 1)
                )
                .frame(maxWidth: 400)

                Spacer()

                // Privacy note
                HStack(spacing: 8) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.white)
                    Text("Reads input timing only — never what you type or see")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.85))
                }
                .padding(.bottom, 20)

                // Open Settings button
                Button {
                    onOpenSettings()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "gear")
                            .font(.system(size: 15, weight: .semibold))
                        Text("Open Accessibility Settings")
                            .font(.system(size: 17, weight: .bold))
                    }
                    .foregroundStyle(bgTop)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(.white)
                    .clipShape(Capsule())
                    .shadow(color: .black.opacity(0.2), radius: 12, y: 6)
                }
                .buttonStyle(.plain)
                .frame(maxWidth: 320)

                Text("This screen closes automatically once access is granted")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.5))
                    .padding(.top, 12)
                    .padding(.bottom, 32)
            }
            .padding(.horizontal, 40)
        }
    }

    // MARK: - Step Components

    private func stepRow(icon: String, title: String, subtitle: String, bgTop: Color) -> some View {
        HStack(spacing: 14) {
            // Icon in a white circle
            ZStack {
                Circle()
                    .fill(.white)
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(bgTop)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.75))
            }

            Spacer()
        }
        .padding(.vertical, 10)
    }

    private func stepConnector() -> some View {
        HStack {
            Rectangle()
                .fill(.white.opacity(0.35))
                .frame(width: 2, height: 12)
                .padding(.leading, 17)
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
