import SwiftUI

/// Visual step-by-step guide for granting Accessibility permission manually.
/// Used in sandboxed (App Store) builds where the system prompt can't auto-appear.
struct PermissionGuideView: View {
    let theme: BlinkTheme
    let onOpenSettings: () -> Void
    let onDone: () -> Void
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
                    .foregroundStyle(accent)
                    .padding(.bottom, 16)

                Text("Grant Accessibility Access")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(fg)
                    .padding(.bottom, 6)

                Text("Blink needs this to detect your typing and mouse patterns")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(fg.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 28)

                // Steps
                VStack(spacing: 0) {
                    stepRow(
                        number: "1",
                        icon: "gear",
                        title: "Open Accessibility Settings",
                        subtitle: "Click the button below to open the right page",
                        fg: fg, accent: accent
                    )

                    stepConnector(fg: fg)

                    stepRow(
                        number: "2",
                        icon: "plus.circle",
                        title: "Click the  +  button",
                        subtitle: "At the bottom-left of the app list",
                        fg: fg, accent: accent
                    )

                    stepConnector(fg: fg)

                    stepRow(
                        number: "3",
                        icon: "magnifyingglass",
                        title: "Find Blink in Applications",
                        subtitle: "Navigate to Applications → select Blink → click Open",
                        fg: fg, accent: accent
                    )

                    stepConnector(fg: fg)

                    stepRow(
                        number: "4",
                        icon: "togglepower",
                        title: "Toggle Blink on",
                        subtitle: "You may need to enter your password",
                        fg: fg, accent: accent
                    )
                }
                .padding(20)
                .background(fg.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .frame(maxWidth: 400)

                Spacer()

                // Why needed
                HStack(spacing: 8) {
                    Image(systemName: "lock.shield")
                        .font(.system(size: 13))
                        .foregroundStyle(fg.opacity(0.6))
                    Text("Blink reads input timing only — never what you type or see")
                        .font(.system(size: 12))
                        .foregroundStyle(fg.opacity(0.6))
                }
                .padding(.bottom, 16)

                // Buttons
                VStack(spacing: 10) {
                    Button {
                        onOpenSettings()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "gear")
                                .font(.system(size: 14))
                            Text("Open Accessibility Settings")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundStyle(theme.backgroundTop(for: colorScheme))
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(fg)
                        .clipShape(Capsule())
                        .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: 320)

                    Button {
                        onDone()
                    } label: {
                        Text("I've already done this")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(fg.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.bottom, 32)
            }
            .padding(.horizontal, 40)
        }
    }

    // MARK: - Step Components

    private func stepRow(number: String, icon: String, title: String, subtitle: String, fg: Color, accent: Color) -> some View {
        HStack(spacing: 14) {
            // Number badge
            ZStack {
                Circle()
                    .fill(accent)
                    .frame(width: 32, height: 32)
                Text(number)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(theme.backgroundTop(for: colorScheme))
            }

            // Icon
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(accent)
                .frame(width: 28)

            // Text
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(fg)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(fg.opacity(0.65))
            }

            Spacer()
        }
        .padding(.vertical, 8)
    }

    private func stepConnector(fg: Color) -> some View {
        HStack {
            Rectangle()
                .fill(fg.opacity(0.15))
                .frame(width: 2, height: 16)
                .padding(.leading, 15)
            Spacer()
        }
    }
}

#Preview("Permission Guide — Peach") {
    PermissionGuideView(
        theme: .peach,
        onOpenSettings: {},
        onDone: {}
    )
    .frame(width: 500, height: 650)
}

#Preview("Permission Guide — Midnight Dark") {
    PermissionGuideView(
        theme: .midnight,
        onOpenSettings: {},
        onDone: {}
    )
    .frame(width: 500, height: 650)
    .preferredColorScheme(.dark)
}

#Preview("Permission Guide — Sage") {
    PermissionGuideView(
        theme: .sage,
        onOpenSettings: {},
        onDone: {}
    )
    .frame(width: 500, height: 650)
}
