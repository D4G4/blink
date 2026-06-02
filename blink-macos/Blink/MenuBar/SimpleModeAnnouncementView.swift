import SwiftUI

/// One-time "did you know?" HUD shown on the first launch after the
/// Simple timer mode toggle ships. Targets users who already chose Smart
/// during onboarding and would otherwise never discover the new option.
/// Persists `simpleTimerModeAnnounced=true` after dismissal so it never
/// reappears.
struct SimpleModeAnnouncementView: View {
    /// Two scenarios share this HUD:
    ///   - `.announce`: one-time "did you know Simple mode exists?" for
    ///     existing Smart users. Primary = "Show me", secondary = "Keep Smart".
    ///   - `.activeByDefault`: confirms Simple mode is now on because the user
    ///     closed setup without choosing. Primary = "Open Preferences",
    ///     secondary = "Got it".
    enum Style { case announce, activeByDefault }

    let theme: BlinkTheme
    var style: Style = .announce
    var onShowMe: () -> Void = {}
    var onDismiss: () -> Void = {}

    @Environment(\.colorScheme) private var colorScheme

    private var title: String {
        switch style {
        case .announce: return "New: Simple timer mode"
        case .activeByDefault: return "Simple timer mode is on"
        }
    }

    private var subtitle: String {
        switch style {
        case .announce:
            return "Run Blink with zero macOS permissions — no typing detection, just a smart-enough 20-min timer."
        case .activeByDefault:
            return "Blink runs a steady 20-min timer with zero permissions. Switch to Smart anytime in Preferences → Flow."
        }
    }

    private var secondaryLabel: String {
        switch style {
        case .announce: return "Keep Smart mode"
        case .activeByDefault: return "Got it"
        }
    }

    private var primaryLabel: String {
        switch style {
        case .announce: return "Show me"
        case .activeByDefault: return "Open Preferences"
        }
    }

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
                    Text(title)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(fg)
                    Text(subtitle)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(fg.opacity(0.85))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(spacing: 8) {
                Button(action: onDismiss) {
                    Text(secondaryLabel)
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
                    Text(primaryLabel)
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
