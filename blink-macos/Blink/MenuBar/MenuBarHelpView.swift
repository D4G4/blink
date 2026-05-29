import SwiftUI

/// Shown when the user taps "Can't find it" on the launch HUD. Explains —
/// with a visual — how menu bar icons get hidden behind the notch / by
/// overflow, gives the honest ways to recover the icon, and offers a
/// guaranteed fallback entry point (Open Preferences) so Blink stays
/// reachable even if the icon never reappears.
struct MenuBarHelpView: View {
    let theme: BlinkTheme
    let onOpenPreferences: () -> Void
    let onDismiss: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    NotchDiagram(theme: theme)
                        .frame(height: 92)
                        .frame(maxWidth: .infinity)
                    explanation
                    recoverySteps
                    fallback
                }
                .padding(28)
            }

            Divider()

            HStack {
                Spacer()
                Button(action: onDismiss) {
                    Text("Got it")
                        .font(.system(size: 13, weight: .semibold))
                        .padding(.horizontal, 18)
                        .padding(.vertical, 7)
                }
                .buttonStyle(.borderedProminent)
                .tint(theme.backgroundTop(for: colorScheme))
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 14)
        }
        .frame(width: 540, height: 620)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Where's the Blink icon?")
                .font(.system(size: 22, weight: .bold, design: .rounded))
            Text("It's running — it just may be hidden in your menu bar.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
    }

    private var explanation: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Why this happens")
                .font(.system(size: 14, weight: .semibold))
            Text("macOS lays out menu bar icons from the right edge, going left. On Macs with a notch — or when you have a lot of menu bar apps — the icons that don't fit get pushed under the notch and become invisible. Blink's icon is there; you just can't see it.")
                .font(.system(size: 13))
                .foregroundStyle(.primary.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var recoverySteps: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("How to bring it back")
                .font(.system(size: 14, weight: .semibold))
            step(number: 1, text: "Hold ⌘ (Command) and drag the Blink icon to the right of the notch — if your menu bar has room there.")
            step(number: 2, text: "If the menu bar is full, quit a few other menu bar apps to free up space, or install a free menu bar manager like Ice (icemenubar.app) to reveal hidden icons.")
        }
    }

    private func step(number: Int, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(number)")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(theme.onBackgroundText(for: colorScheme))
                .frame(width: 22, height: 22)
                .background(Circle().fill(theme.backgroundTop(for: colorScheme)))
            Text(text)
                .font(.system(size: 13))
                .foregroundStyle(.primary.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var fallback: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("In the meantime")
                .font(.system(size: 14, weight: .semibold))
            Text("You can always open Blink's settings from here, no menu bar icon required.")
                .font(.system(size: 13))
                .foregroundStyle(.primary.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
            Button(action: onOpenPreferences) {
                HStack(spacing: 8) {
                    Image(systemName: "gearshape.fill")
                    Text("Open Blink Settings")
                }
                .font(.system(size: 13, weight: .semibold))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .buttonStyle(.bordered)
        }
    }
}

/// Stylized menu bar showing icons being clipped behind the notch.
private struct NotchDiagram: View {
    let theme: BlinkTheme

    var body: some View {
        GeometryReader { geo in
            let barHeight: CGFloat = 38
            let notchWidth: CGFloat = 120
            let notchHeight: CGFloat = 26
            let iconSize: CGFloat = 22
            let centerX = geo.size.width / 2

            ZStack(alignment: .top) {
                // Menu bar strip
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Color.black.opacity(0.88))
                    .frame(height: barHeight)

                // System icons on the right (always visible)
                HStack(spacing: 14) {
                    Spacer()
                    Image(systemName: "wifi")
                    Image(systemName: "battery.75")
                    Image(systemName: "magnifyingglass")
                    Text("9:41").font(.system(size: 12, weight: .medium))
                }
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.9))
                .padding(.horizontal, 14)
                .frame(height: barHeight)

                // Blink icon being swallowed by the notch (just left of it)
                Image(theme.iconAsset)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: iconSize, height: iconSize)
                    .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                    .opacity(0.45)
                    .position(x: centerX - notchWidth / 2 - 4, y: barHeight / 2)

                // A faded neighbor further left, also clipped
                Image(systemName: "app.dashed")
                    .font(.system(size: 16))
                    .foregroundStyle(.white.opacity(0.4))
                    .position(x: centerX - notchWidth / 2 - 34, y: barHeight / 2)

                // The notch itself, on top so it visually covers the icons
                RoundedRectangle(cornerRadius: 0, style: .continuous)
                    .fill(Color.black)
                    .frame(width: notchWidth, height: notchHeight)
                    .clipShape(
                        .rect(bottomLeadingRadius: 12, bottomTrailingRadius: 12)
                    )
                    .position(x: centerX, y: notchHeight / 2)
            }
        }
    }
}

#Preview("Help – Peach") {
    MenuBarHelpView(theme: .peach, onOpenPreferences: {}, onDismiss: {})
}

#Preview("Help – Midnight") {
    MenuBarHelpView(theme: .midnight, onOpenPreferences: {}, onDismiss: {})
        .preferredColorScheme(.dark)
}
