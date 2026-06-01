import SwiftUI

/// First page of the post-onboarding PermissionFlow. Frames the
/// detection-mode decision as an upfront, equal-weight choice before
/// the user ever sees the (visually heavy) Input Monitoring permission
/// page. Replaces the previous flow that dumped the user straight onto
/// the permission UI with a tiny "skip" link at the bottom.
///
/// Two paths:
///   - Smart  → advance to MicrophonePermissionPage → IM page
///   - Simple → complete the flow with basicMode=true (no permissions
///              requested at all)
struct DetectionModeChoicePage: View {
    let theme: BlinkTheme
    /// Fires when the user picks Smart — advance to the mic step.
    let onPickSmart: () -> Void
    /// Fires when the user picks Simple — complete the flow with
    /// basicMode=true, skipping mic + IM entirely.
    let onPickSimple: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        GeometryReader { proxy in
            content(availableHeight: proxy.size.height)
        }
    }

    @ViewBuilder
    private func content(availableHeight: CGFloat) -> some View {
        let isCompact = availableHeight < 700
        let iconSize: CGFloat = isCompact ? 38 : 48
        let titleSize: CGFloat = isCompact ? 24 : 28
        let outerVPad: CGFloat = isCompact ? 20 : 40

        let heroFg = theme.onBackgroundText(for: colorScheme)
        let bodyFg = theme.onBackgroundBodyText(for: colorScheme)
        let bgTop = theme.backgroundTop(for: colorScheme)

        ZStack(alignment: .topLeading) {
            theme.backgroundGradient(for: colorScheme).ignoresSafeArea()

            VStack(spacing: 0) {
                Image(systemName: "eye")
                    .font(.system(size: iconSize, weight: .light))
                    .foregroundStyle(heroFg)
                    .padding(.bottom, 10)

                Text("How should Blink find your breaks?")
                    .font(.system(size: titleSize, weight: .bold, design: .rounded))
                    .foregroundStyle(heroFg)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                Text("Two ways to begin. Either feels good — and you can swap any time.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(heroFg.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .padding(.top, 4)

                Spacer(minLength: 32)

                // Two equal-width cards. Mirrors FlowSensitivityView's
                // presetCard pattern: centered icon, title, short
                // description, click-to-commit. Equal heights enforced
                // by HStack default + fixed inner spacing.
                HStack(spacing: 14) {
                    modeCard(
                        title: "Smart",
                        description: "Knows when you're in flow. Slips breaks in between thoughts — never mid-sentence.",
                        icon: "sparkles",
                        permissionIcon: "lock.shield",
                        permissionNote: "Needs Input Monitoring",
                        recommended: true,
                        heroFg: heroFg, bgTop: bgTop,
                        action: onPickSmart
                    )
                    modeCard(
                        title: "Simple",
                        description: "A steady 20-minute rhythm. Quiet, predictable, asks nothing of your Mac.",
                        icon: "hourglass",
                        permissionIcon: "checkmark.shield",
                        permissionNote: "Zero permissions",
                        recommended: false,
                        heroFg: heroFg, bgTop: bgTop,
                        action: onPickSimple
                    )
                }
                .padding(.horizontal, 60)
                .frame(maxWidth: 640)

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.top, outerVPad)
            .padding(.bottom, outerVPad)
        }
    }

    /// Single card — centered icon, title, short description. Click commits
    /// the choice. Mirrors FlowSensitivityView.presetCard's visual rhythm so
    /// the choice feels like a sibling step to the flow-sensitivity picker.
    /// "Recommended" pill floats above the icon (doesn't shift card height).
    private func modeCard(title: String, description: String, icon: String, permissionIcon: String, permissionNote: String, recommended: Bool, heroFg: Color, bgTop: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 10) {
                // Reserved height for the Recommended pill, so both
                // cards align icon-to-icon regardless of which one is
                // marked recommended.
                ZStack {
                    if recommended {
                        Text("Recommended")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(bgTop)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(heroFg))
                    }
                }
                .frame(height: 26)

                Image(systemName: icon)
                    .font(.system(size: 40, weight: .light))
                    .foregroundStyle(heroFg)

                Text(title)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(heroFg)

                Text(description)
                    .font(.system(size: 14))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .foregroundStyle(heroFg.opacity(0.85))
                    .lineSpacing(2)

                // Permission footnote — small, subtle, but explicit so
                // the trade-off is visible before the user commits.
                HStack(spacing: 5) {
                    Image(systemName: permissionIcon)
                        .font(.system(size: 11, weight: .medium))
                    Text(permissionNote)
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(heroFg.opacity(0.7))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Capsule().fill(heroFg.opacity(0.12)))
                .padding(.top, 4)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 22)
            .padding(.horizontal, 18)
            .background(heroFg.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(heroFg.opacity(recommended ? 0.4 : 0), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview("Peach") {
    DetectionModeChoicePage(theme: .peach, onPickSmart: {}, onPickSimple: {})
        .frame(width: 900, height: 650)
}

#Preview("Midnight") {
    DetectionModeChoicePage(theme: .midnight, onPickSmart: {}, onPickSimple: {})
        .frame(width: 900, height: 650)
        .preferredColorScheme(.dark)
}
