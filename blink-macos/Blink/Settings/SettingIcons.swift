import SwiftUI

/// Hand-rolled SwiftUI icons used by `SettingsView` for settings rows
/// that don't have a good SF Symbol equivalent. Each icon is sized to
/// match the leading column width and tinted with the active theme's
/// accent color so they sit cleanly alongside SF Symbol rows.
///
/// Why custom views (not SVG asset files):
/// - Tint follows the theme accent without baking it into a raster.
/// - Sharper at any size — no scaling artifacts.
/// - Lives next to the setting it describes, easier to keep in sync.

/// Tiny mockup of the macOS menu bar with the Blink eye glyph and a
/// "20:00" countdown. Used by the "Show countdown timer" toggle so the
/// effect is visually obvious without reading the label.
struct CountdownTimerIcon: View {
    var accent: Color
    var foreground: Color = .primary

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Translucent screen / window underneath, just to give the
            // menu bar somewhere to "live" — a 1pt rounded outline.
            RoundedRectangle(cornerRadius: 4)
                .stroke(foreground.opacity(0.25), lineWidth: 1)

            // The menu bar strip itself.
            VStack(spacing: 0) {
                HStack(spacing: 3) {
                    Spacer(minLength: 0)
                    // Eye glyph, theme-tinted.
                    Image(systemName: "eye.fill")
                        .font(.system(size: 6))
                        .foregroundStyle(accent)
                    // Countdown number — fixed copy, signals "20:00 left."
                    Text("20:00")
                        .font(.system(size: 5, weight: .medium, design: .monospaced))
                        .foregroundStyle(foreground.opacity(0.85))
                        .padding(.trailing, 2)
                }
                .padding(.vertical, 1.5)
                .padding(.horizontal, 2)
                .background(foreground.opacity(0.08))
                .clipShape(
                    .rect(
                        topLeadingRadius: 4,
                        bottomLeadingRadius: 0,
                        bottomTrailingRadius: 0,
                        topTrailingRadius: 4
                    )
                )

                Spacer(minLength: 0)
            }
        }
        .frame(width: 32, height: 22)
    }
}

/// Mockup of the break overlay's dark mode: a window-shaped frame with
/// a dark veil covering most of it and a faint timer ring centered.
/// Used by the "Use dark overlay" toggle.
struct DarkOverlayIcon: View {
    var accent: Color
    var foreground: Color = .primary

    var body: some View {
        ZStack {
            // Outer window frame.
            RoundedRectangle(cornerRadius: 4)
                .stroke(foreground.opacity(0.25), lineWidth: 1)

            // Dark overlay fill — the feature being toggled.
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.black.opacity(0.88))
                .padding(2)

            // Faint timer ring centered in the dark — visual cue that
            // a break overlay is active.
            Circle()
                .stroke(accent.opacity(0.75), lineWidth: 1)
                .frame(width: 10, height: 10)
        }
        .frame(width: 32, height: 22)
    }
}

#Preview("Icons - light") {
    HStack(spacing: 20) {
        CountdownTimerIcon(accent: .orange)
        DarkOverlayIcon(accent: .orange)
    }
    .padding(20)
}

#Preview("Icons - dark") {
    HStack(spacing: 20) {
        CountdownTimerIcon(accent: .orange, foreground: .white)
        DarkOverlayIcon(accent: .orange, foreground: .white)
    }
    .padding(20)
    .background(Color.black)
    .preferredColorScheme(.dark)
}
