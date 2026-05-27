import SwiftUI

/// Brief themed HUD that appears at the top-right of the screen on launch
/// to confirm Blink is running. Replaces the previous "auto-open the menu
/// bar popup" approach, which couldn't surface anything when the user's
/// menu bar icon was hidden by the notch, Bartender, or sheer overflow.
///
/// The HUD is its own borderless window — it doesn't depend on the menu
/// bar icon being visible at all.
struct LaunchHUDView: View {
    let theme: BlinkTheme
    let onTap: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var pulseArrow = false

    var body: some View {
        let fg = theme.onBackgroundText(for: colorScheme)
        let bgTop = theme.backgroundTop(for: colorScheme)

        Button(action: onTap) {
            HStack(spacing: 14) {
                Image(theme.iconAsset)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 40, height: 40)
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                    .shadow(color: .black.opacity(0.15), radius: 4, y: 2)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Blink is now active")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(fg)
                    Text("Find the timer in your menu bar")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(fg.opacity(0.85))
                }

                Spacer(minLength: 8)

                // Arrow points up-left because the HUD is anchored to the
                // top-right of the screen and macOS menu bar status items
                // extend leftward from the right edge — so Blink's icon
                // sits to the LEFT of the HUD, not the right.
                Image(systemName: "arrow.up.left")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(fg)
                    .offset(x: pulseArrow ? -3 : 0)
                    .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: pulseArrow)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(width: 320)
            .background(
                theme.backgroundGradient(for: colorScheme)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(fg.opacity(0.15), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.25), radius: 16, y: 6)
        }
        .buttonStyle(.plain)
        .onAppear { pulseArrow = true }
        .help("Click to open Blink")
        // Silence unused-var warning when in light mode
        .background(Color.clear.opacity(bgTop == fg ? 0 : 0))
    }
}

#Preview("Peach") {
    LaunchHUDView(theme: .peach, onTap: {})
        .padding(20)
        .background(Color.gray.opacity(0.2))
}

#Preview("Sage") {
    LaunchHUDView(theme: .sage, onTap: {})
        .padding(20)
        .background(Color.gray.opacity(0.2))
}

#Preview("Midnight") {
    LaunchHUDView(theme: .midnight, onTap: {})
        .padding(20)
        .background(Color.black)
        .preferredColorScheme(.dark)
}
