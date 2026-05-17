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
                // Top bar: centered icon + title
                VStack(spacing: 4) {
                    HStack(spacing: 10) {
                        Image(systemName: "hand.raised.circle.fill")
                            .font(.system(size: 24, weight: .light))
                            .foregroundStyle(fg)
                        Text("Grant Accessibility Access")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(fg)
                    }
                    Text("Blink needs this to detect your input timing")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(fg)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 20)
                .padding(.bottom, 16)

                // Main content: screenshot + steps side by side
                HStack(spacing: 24) {
                    // LEFT: Hero screenshot
                    annotatedScreenshot(accent: accent, fg: fg)

                    // RIGHT: Steps (centered)
                    VStack(alignment: .leading, spacing: 0) {
                        stepRow(icon: "plus.circle.fill", title: "Click  +  button", fg: fg, bgTop: bgTop)
                        stepConnector(fg: fg)
                        blinkIconStep(fg: fg)
                        stepConnector(fg: fg)
                        toggleStep(accent: accent, fg: fg)
                    }
                    .padding(16)
                    .background(fg.opacity(0.15))
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
                        .background(fg)
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
                        .foregroundStyle(fg)
                        .frame(height: 40)
                        .padding(.horizontal, 20)
                        .background(fg.opacity(0.25))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }

                if showError {
                    Text("Permission not detected — make sure Blink is toggled on in Accessibility")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(fg)
                        .padding(.top, 6)
                }

                Spacer()
                    .frame(height: 20)
            }
        }
    }

    // MARK: - Annotated Screenshot

    private func annotatedScreenshot(accent: Color, fg: Color) -> some View {
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
                    .stroke(fg.opacity(0.25), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.35), radius: 20, y: 10)
    }

    // MARK: - Step Components

    private func stepRow(icon: String, title: String, fg: Color, bgTop: Color) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 4)
                    .fill(fg)
                    .frame(width: 32, height: 18)
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(bgTop)
            }
            Text(title)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(fg)
        }
        .padding(.vertical, 8)
    }

    private func blinkIconStep(fg: Color) -> some View {
        HStack(spacing: 12) {
            Image(theme.iconAsset)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 36, height: 36)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            Text("Find Blink → Open")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(fg)
        }
        .padding(.vertical, 8)
    }

    private func toggleStep(accent: Color, fg: Color) -> some View {
        HStack(spacing: 12) {
            // Mini macOS-style toggle (on state) with theme color
            ZStack(alignment: .trailing) {
                Capsule()
                    .fill(accent)
                    .overlay(Capsule().stroke(fg.opacity(0.3), lineWidth: 1))
                    .frame(width: 36, height: 20)
                Circle()
                    .fill(theme.textOnAccent(for: colorScheme))
                    .frame(width: 17, height: 17)
                    .shadow(color: .black.opacity(0.15), radius: 1, y: 1)
                    .padding(.trailing, 1.5)
            }
            Text("Toggle on")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(fg)
        }
        .padding(.vertical, 8)
    }

    private func stepConnector(fg: Color) -> some View {
        Rectangle()
            .fill(fg.opacity(0.3))
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
