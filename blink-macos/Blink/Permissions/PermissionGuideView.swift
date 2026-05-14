import SwiftUI

/// Visual guide for granting Accessibility permission manually.
/// Landscape layout — hero screenshot on left, steps on right, button at bottom full width.
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

            VStack(spacing: 0) {
                // Top bar: centered icon + title
                VStack(spacing: 4) {
                    HStack(spacing: 10) {
                        Image(systemName: "hand.raised.circle.fill")
                            .font(.system(size: 24, weight: .light))
                            .foregroundStyle(.white)
                        Text("Grant Accessibility Access")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                    }
                    Text("Blink needs this to detect your input timing")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.8))
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 20)
                .padding(.bottom, 16)

                // Main content: screenshot + steps side by side
                HStack(spacing: 24) {
                    // LEFT: Hero screenshot
                    annotatedScreenshot(accent: accent, bgTop: bgTop)

                    // RIGHT: Steps (centered)
                    VStack(spacing: 0) {
                        Spacer()
                        VStack(spacing: 0) {
                            stepRow(icon: "gear", title: "Open Settings", bgTop: bgTop)
                            stepConnector()
                            stepRow(icon: "plus.circle.fill", title: "Click  +  button", bgTop: bgTop)
                            stepConnector()
                            blinkIconStep()
                            stepConnector()
                            stepRow(icon: "switch.2", title: "Toggle on", bgTop: bgTop)
                        }
                        Spacer()
                    }
                    .padding(16)
                    .background(.white.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .frame(width: 200)
                }
                .padding(.horizontal, 28)

                Spacer()

                // Bottom: button
                Button {
                    onOpenSettings()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "gear")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Open Accessibility Settings")
                            .font(.system(size: 15, weight: .bold))
                    }
                    .foregroundStyle(bgTop)
                    .frame(width: 280, height: 44)
                    .background(.white)
                    .clipShape(Capsule())
                    .shadow(color: .black.opacity(0.2), radius: 10, y: 5)
                }
                .buttonStyle(.plain)
                .padding(.bottom, 20)
            }
        }
    }

    // MARK: - Annotated Screenshot

    private func annotatedScreenshot(accent: Color, bgTop: Color) -> some View {
        ZStack(alignment: .bottomLeading) {
            Image("AccessibilitySettings")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(accent.opacity(0.06))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(.white.opacity(0.25), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.35), radius: 20, y: 10)

            // Highlight + label overlaid using geometry-relative positioning
            GeometryReader { geo in
                let plusX: CGFloat = geo.size.width * 0.08
                let plusY: CGFloat = geo.size.height * 0.88

                // Circle on "+" button
                Circle()
                    .stroke(.white, lineWidth: 2.5)
                    .frame(width: 26, height: 26)
                    .background(Circle().fill(.white.opacity(0.25)))
                    .position(x: plusX, y: plusY)

                // "Click +" label with arrow above the circle
                VStack(spacing: 2) {
                    Text("Click  +")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(bgTop)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(.white)
                        .clipShape(Capsule())
                        .shadow(color: .black.opacity(0.15), radius: 4, y: 2)

                    Image(systemName: "arrow.down")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                }
                .position(x: plusX + 40, y: plusY - 40)
            }
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
        .frame(width: 700, height: 420)
}

#Preview("Permission Guide — Midnight") {
    PermissionGuideView(theme: .midnight, onOpenSettings: {})
        .frame(width: 700, height: 420)
        .preferredColorScheme(.dark)
}

#Preview("Permission Guide — Sage") {
    PermissionGuideView(theme: .sage, onOpenSettings: {})
        .frame(width: 700, height: 420)
}
