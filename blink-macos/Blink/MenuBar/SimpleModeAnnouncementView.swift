import SwiftUI

/// One-time "did you know?" HUD shown on the first launch after the
/// Simple timer mode toggle ships. Targets users who already chose Smart
/// during onboarding and would otherwise never discover the new option.
/// Persists `simpleTimerModeAnnounced=true` after dismissal so it never
/// reappears.
struct SimpleModeAnnouncementView: View {
    let theme: BlinkTheme
    var onShowMe: () -> Void = {}
    var onDismiss: () -> Void = {}

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let fg = theme.onBackgroundText(for: colorScheme)

        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "hourglass")
                    .font(.system(size: 22, weight: .light))
                    .foregroundStyle(fg)
                    .frame(width: 40, height: 40)
                    .background(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(fg.opacity(0.15))
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text("New: Simple timer mode")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(fg)
                    Text("Run Blink with zero macOS permissions — no typing detection, just a smart-enough 20-min timer.")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(fg.opacity(0.85))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(spacing: 8) {
                Button(action: onDismiss) {
                    Text("Keep Smart mode")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(fg)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(fg.opacity(0.35), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)

                Button(action: onShowMe) {
                    Text("Show me")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(theme.backgroundTop(for: colorScheme))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(fg)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(width: 360)
        .background(theme.backgroundGradient(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(fg.opacity(0.15), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.25), radius: 16, y: 6)
    }
}

#Preview("Peach") {
    SimpleModeAnnouncementView(theme: .peach)
        .padding(20)
        .background(Color.gray.opacity(0.2))
}

#Preview("Midnight") {
    SimpleModeAnnouncementView(theme: .midnight)
        .padding(20)
        .background(Color.black)
        .preferredColorScheme(.dark)
}
