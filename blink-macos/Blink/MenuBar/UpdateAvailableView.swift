import SwiftUI

/// HUD shown when UpdateChecker detects a newer version on launch or
/// during the 24h periodic check. Visually mirrors
/// SimpleModeAnnouncementView so the system has one consistent
/// announcement vocabulary.
///
/// Surfacing logic is in AppState.maybeShowUpdateAvailable — it only
/// fires when the latest version differs from updateAnnouncedVersion
/// in UserDefaults, so a user who's already seen a prompt for v1.5
/// doesn't get re-prompted for v1.5 on every launch (but DOES get
/// re-prompted when v1.6 drops).
struct UpdateAvailableView: View {
    let theme: BlinkTheme
    let version: String
    /// Determines the primary CTA — "Copy brew command" for Homebrew
    /// installs, "Download" for DMG installs. App Store installs never
    /// reach this view because UpdateChecker short-circuits there.
    let installSource: UpdateChecker.InstallSource
    /// Primary action — semantics depend on installSource. For
    /// Homebrew: copy `brew upgrade` to clipboard. For DMG: open the
    /// download URL.
    var onPrimary: () -> Void = {}
    var onSkip: () -> Void = {}

    @Environment(\.colorScheme) private var colorScheme

    private var primaryLabel: String {
        switch installSource {
        case .homebrew: return "Copy brew command"
        case .dmg, .appStore: return "Download"
        }
    }

    private var subtitle: String {
        switch installSource {
        case .homebrew:
            return "Blink v\(version) is on Homebrew — copy the upgrade command."
        case .dmg, .appStore:
            return "Blink v\(version) is ready to download."
        }
    }

    var body: some View {
        let fg = theme.onBackgroundText(for: colorScheme)

        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 22, weight: .light))
                    .foregroundStyle(fg)
                    .frame(width: 40, height: 40)
                    .background(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(fg.opacity(0.15))
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text("Update available")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(fg)
                    Text(subtitle)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(fg.opacity(0.85))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(spacing: 8) {
                Button(action: onSkip) {
                    Text("Skip this version")
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

                Button(action: onPrimary) {
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

#Preview("Peach - DMG") {
    UpdateAvailableView(theme: .peach, version: "1.5.0", installSource: .dmg)
        .padding(20)
        .background(Color.gray.opacity(0.2))
}

#Preview("Peach - Homebrew") {
    UpdateAvailableView(theme: .peach, version: "1.5.0", installSource: .homebrew)
        .padding(20)
        .background(Color.gray.opacity(0.2))
}

#Preview("Midnight - DMG") {
    UpdateAvailableView(theme: .midnight, version: "1.5.0", installSource: .dmg)
        .padding(20)
        .background(Color.black)
        .preferredColorScheme(.dark)
}

#Preview("Midnight - Homebrew") {
    UpdateAvailableView(theme: .midnight, version: "1.5.0", installSource: .homebrew)
        .padding(20)
        .background(Color.black)
        .preferredColorScheme(.dark)
}
