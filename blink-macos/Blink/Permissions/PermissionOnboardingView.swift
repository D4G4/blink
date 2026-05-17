import SwiftUI

struct PermissionOnboardingView: View {
    let theme: BlinkTheme
    let onContinue: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let fg = theme.onBackgroundText(for: colorScheme)

        ZStack {
            theme.backgroundGradient(for: colorScheme)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Shield icon
                Image(systemName: "hand.raised.circle.fill")
                    .font(.system(size: 56, weight: .light))
                    .foregroundStyle(theme.accent(for: colorScheme))
                    .padding(.bottom, 20)

                Text("One more thing")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(fg)
                    .padding(.bottom, 8)

                Text("Blink needs Accessibility permission to work")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(fg)
                    .padding(.bottom, 36)

                // Explanation cards
                VStack(spacing: 12) {
                    permissionCard(
                        icon: "keyboard",
                        title: "Detects typing & mouse patterns",
                        description: "So breaks come at the right time, not mid-thought",
                        fg: fg
                    )
                    permissionCard(
                        icon: "eye.slash",
                        title: "No keystrokes or content recorded",
                        description: "Only timing patterns — never what you type",
                        fg: fg
                    )
                    permissionCard(
                        icon: "brain.head.profile",
                        title: "Powers smart flow detection",
                        description: "Extends breaks when you're focused, pauses when you're away",
                        fg: fg
                    )
                }
                .frame(maxWidth: 400)
                .padding(.bottom, 36)

                HStack(spacing: 8) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 14))
                        .foregroundStyle(fg)
                    Text("macOS will ask you to grant access in System Settings")
                        .font(.system(size: 14))
                        .foregroundStyle(fg)
                }
                .padding(.bottom, 20)

                Button {
                    onContinue()
                } label: {
                    Text("Grant Access")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(theme.backgroundTop(for: colorScheme))
                        .frame(width: 200, height: 48)
                        .background(fg)
                        .clipShape(Capsule())
                        .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
                }
                .buttonStyle(.plain)

                Spacer()
            }
            .padding(.horizontal, 40)
        }
    }

    private func permissionCard(icon: String, title: String, description: String, fg: Color) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(theme.backgroundTop(for: colorScheme))
                .frame(width: 40, height: 40)
                .background(fg)
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(fg)
                Text(description)
                    .font(.system(size: 13))
                    .foregroundStyle(fg)
            }

            Spacer()
        }
        .padding(16)
        .background(fg.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview("Permission - Peach") {
    PermissionOnboardingView(theme: .peach, onContinue: {})
        .frame(width: 500, height: 600)
}

#Preview("Permission - Midnight") {
    PermissionOnboardingView(theme: .midnight, onContinue: {})
        .frame(width: 500, height: 600)
}
