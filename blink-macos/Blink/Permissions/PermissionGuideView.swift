import SwiftUI

/// Visual guide for granting Accessibility permission manually.
/// Landscape layout — image-focused with minimal text.
/// Auto-dismissed by AppState polling when permission is granted.
struct PermissionGuideView: View {
    let theme: BlinkTheme
    let onOpenSettings: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let accent = theme.accent(for: colorScheme)
        let bgTop = theme.backgroundTop(for: colorScheme)

        ZStack {
            theme.backgroundGradient(for: colorScheme)
                .ignoresSafeArea()

            RadialGradient(
                colors: [.white.opacity(0.1), .clear],
                center: .top,
                startRadius: 50,
                endRadius: 400
            )

            HStack(spacing: 32) {
                // LEFT: Annotated screenshot (hero)
                annotatedScreenshot(accent: accent, bgTop: bgTop)

                // RIGHT: Title + steps + button
                VStack(alignment: .leading, spacing: 0) {
                    Spacer()

                    // Header
                    Image(systemName: "hand.raised.circle.fill")
                        .font(.system(size: 36, weight: .light))
                        .foregroundStyle(.white)
                        .padding(.bottom, 12)

                    Text("Grant Access")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.bottom, 4)

                    Text("Blink needs Accessibility to detect input timing")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.85))
                        .padding(.bottom, 24)

                    // Steps
                    VStack(alignment: .leading, spacing: 0) {
                        stepRow(icon: "gear", title: "Open Settings", bgTop: bgTop)
                        stepConnector()
                        stepRow(icon: "plus.circle.fill", title: "Click  +  button", bgTop: bgTop)
                        stepConnector()
                        blinkIconStep()
                        stepConnector()
                        stepRow(icon: "switch.2", title: "Toggle on", bgTop: bgTop)
                    }
                    .padding(16)
                    .background(.white.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 14))

                    Spacer()

                    // Privacy
                    HStack(spacing: 6) {
                        Image(systemName: "lock.shield.fill")
                            .font(.system(size: 11))
                        Text("Reads timing only — never content")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(.bottom, 12)

                    // Button
                    Button {
                        onOpenSettings()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "gear")
                                .font(.system(size: 13, weight: .semibold))
                            Text("Open Settings")
                                .font(.system(size: 15, weight: .bold))
                        }
                        .foregroundStyle(bgTop)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(.white)
                        .clipShape(Capsule())
                        .shadow(color: .black.opacity(0.2), radius: 10, y: 5)
                    }
                    .buttonStyle(.plain)

                    Text("Closes automatically once granted")
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.4))
                        .frame(maxWidth: .infinity)
                        .padding(.top, 8)
                        .padding(.bottom, 16)
                }
                .frame(width: 240)
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 24)
        }
    }

    // MARK: - Annotated Screenshot

    private func annotatedScreenshot(accent: Color, bgTop: Color) -> some View {
        ZStack(alignment: .bottomLeading) {
            Image("AccessibilitySettings")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(accent.opacity(0.06))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(.white.opacity(0.25), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.35), radius: 20, y: 10)

            // Pulsing highlight on the "+" button
            Circle()
                .stroke(.white, lineWidth: 2.5)
                .frame(width: 36, height: 36)
                .background(Circle().fill(.white.opacity(0.25)))
                .offset(x: 22, y: -14)

            // "Click +" label with arrow
            HStack(spacing: 4) {
                Text("Click  +")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(bgTop)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.white)
                    .clipShape(Capsule())
                    .shadow(color: .black.opacity(0.15), radius: 4, y: 2)

                Image(systemName: "arrow.turn.left.down")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
            }
            .offset(x: 65, y: -6)
        }
    }

    // MARK: - Step Components

    private func stepRow(icon: String, title: String, bgTop: Color) -> some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(.white)
                    .frame(width: 28, height: 28)
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(bgTop)
            }
            Text(title)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
            Spacer()
        }
        .padding(.vertical, 6)
    }

    private func blinkIconStep() -> some View {
        HStack(spacing: 10) {
            Image(theme.iconAsset)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 28, height: 28)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            Text("Find Blink → Open")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
            Spacer()
        }
        .padding(.vertical, 6)
    }

    private func stepConnector() -> some View {
        Rectangle()
            .fill(.white.opacity(0.3))
            .frame(width: 2, height: 8)
            .padding(.leading, 13)
    }
}

#Preview("Permission Guide — Peach") {
    PermissionGuideView(theme: .peach, onOpenSettings: {})
        .frame(width: 700, height: 480)
}

#Preview("Permission Guide — Midnight") {
    PermissionGuideView(theme: .midnight, onOpenSettings: {})
        .frame(width: 700, height: 480)
        .preferredColorScheme(.dark)
}

#Preview("Permission Guide — Sage") {
    PermissionGuideView(theme: .sage, onOpenSettings: {})
        .frame(width: 700, height: 480)
}
