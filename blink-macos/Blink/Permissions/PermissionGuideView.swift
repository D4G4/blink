import SwiftUI

/// Visual guide for granting Accessibility permission manually.
/// Landscape layout — hero screenshot on left, steps on right, button at bottom full width.
/// Auto-dismissed by AppState polling when permission is granted.
struct PermissionGuideView: View {
    let theme: BlinkTheme
    let onOpenSettings: () -> Void
    let onConfirmGranted: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    @State private var showError = false

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
                    VStack(alignment: .leading, spacing: 0) {
                        stepRow(icon: "plus.circle.fill", title: "Click  +  button", bgTop: bgTop)
                        stepConnector()
                        blinkIconStep()
                        stepConnector()
                        toggleStep(accent: accent)
                    }
                    .padding(16)
                    .background(.white.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .frame(width: 200)
                }
                .padding(.horizontal, 28)

                Spacer()

                // Bottom: two buttons
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
                        .background(.white)
                        .clipShape(Capsule())
                        .shadow(color: .black.opacity(0.2), radius: 10, y: 5)
                    }
                    .buttonStyle(.plain)

                    Button {
                        onConfirmGranted()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 12, weight: .semibold))
                            Text("I've granted access")
                                .font(.system(size: 14, weight: .bold))
                        }
                        .foregroundStyle(.white)
                        .frame(height: 40)
                        .padding(.horizontal, 20)
                        .background(.white.opacity(0.25))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }

                if showError {
                    Text("Permission not detected — make sure Blink is toggled on in Accessibility")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white)
                        .padding(.top, 6)
                }

                Spacer()
                    .frame(height: 20)
            }
        }
    }

    // MARK: - Annotated Screenshot

    private func annotatedScreenshot(accent: Color, bgTop: Color) -> some View {
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
    }

    // MARK: - Step Components

    private func stepRow(icon: String, title: String, bgTop: Color) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 4)
                    .fill(.white.opacity(0.85))
                    .frame(width: 32, height: 18)
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.black.opacity(0.4))
            }
            Text(title)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
        }
        .padding(.vertical, 8)
    }

    private func blinkIconStep() -> some View {
        HStack(spacing: 12) {
            Image(theme.iconAsset)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 36, height: 36)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            Text("Find Blink → Open")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
        }
        .padding(.vertical, 8)
    }

    private func toggleStep(accent: Color) -> some View {
        HStack(spacing: 12) {
            // Mini macOS-style toggle (on state) with theme color
            ZStack(alignment: .trailing) {
                Capsule()
                    .fill(accent)
                    .frame(width: 36, height: 20)
                Circle()
                    .fill(.white)
                    .frame(width: 17, height: 17)
                    .shadow(color: .black.opacity(0.15), radius: 1, y: 1)
                    .padding(.trailing, 1.5)
            }
            Text("Toggle on")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
        }
        .padding(.vertical, 8)
    }

    private func stepConnector() -> some View {
        Rectangle()
            .fill(.white.opacity(0.3))
            .frame(width: 2, height: 10)
            .padding(.leading, 17)
    }
}

#Preview("Permission Guide — Peach") {
    PermissionGuideView(theme: .peach, onOpenSettings: {}, onConfirmGranted: {})
        .frame(width: 700, height: 420)
}

#Preview("Permission Guide — Midnight") {
    PermissionGuideView(theme: .midnight, onOpenSettings: {}, onConfirmGranted: {})
        .frame(width: 700, height: 420)
        .preferredColorScheme(.dark)
}

#Preview("Permission Guide — Sage") {
    PermissionGuideView(theme: .sage, onOpenSettings: {}, onConfirmGranted: {})
        .frame(width: 700, height: 420)
}
