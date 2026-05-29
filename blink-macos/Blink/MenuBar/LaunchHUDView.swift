import SwiftUI

/// Themed HUD that appears at the top-right of the screen on launch to
/// confirm Blink is running and help the user locate its menu bar icon.
/// Replaces the previous "auto-open the menu bar popup" approach, which
/// couldn't surface anything when the user's menu bar icon was hidden by
/// the notch, Bartender, or sheer overflow.
///
/// The HUD is its own borderless window — it doesn't depend on the menu
/// bar icon being visible at all. It's persistent (no auto-dismiss) and
/// shown on every launch: "I've found it" dismisses it, "Can't find it"
/// opens the help dialog.
struct LaunchHUDView: View {
    let theme: BlinkTheme
    var onFound: () -> Void = {}
    var onCantFind: () -> Void = {}

    @Environment(\.colorScheme) private var colorScheme
    @State private var pulseArrow = false

    var body: some View {
        let fg = theme.onBackgroundText(for: colorScheme)

        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                appIcon

                VStack(alignment: .leading, spacing: 2) {
                    Text("Blink is now active")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(fg)
                    Text("Can you see the timer in your menu bar?")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(fg.opacity(0.85))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                // Points up-left: status items extend leftward from the
                // right edge, so Blink's icon sits to the LEFT of the HUD.
                Image(systemName: "arrow.up.left")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(fg)
                    .offset(x: pulseArrow ? -3 : 0)
                    .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: pulseArrow)
            }

            HStack(spacing: 8) {
                Button(action: onCantFind) {
                    Text("Can't find it")
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

                Button(action: onFound) {
                    Text("I've found it")
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
        .frame(width: 340)
        .background(theme.backgroundGradient(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(fg.opacity(0.15), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.25), radius: 16, y: 6)
        .onAppear { pulseArrow = true }
    }

    private var appIcon: some View {
        Image(theme.iconAsset)
            .resizable()
            .interpolation(.high)
            .aspectRatio(contentMode: .fit)
            .frame(width: 40, height: 40)
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
    }
}

#Preview("Peach") {
    LaunchHUDView(theme: .peach)
        .padding(20)
        .background(Color.gray.opacity(0.2))
}

#Preview("Midnight") {
    LaunchHUDView(theme: .midnight)
        .padding(20)
        .background(Color.black)
        .preferredColorScheme(.dark)
}

#Preview("Sage") {
    LaunchHUDView(theme: .sage)
        .padding(20)
        .background(Color.gray.opacity(0.2))
}
