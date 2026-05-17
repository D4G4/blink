using Microsoft.UI;
using Windows.UI;

namespace Blink.App.Theme;

public sealed record BlinkTheme(
    string Id,
    string Name,
    Color BackgroundTopLight,
    Color BackgroundBottomLight,
    Color AccentLight,
    Color OverlayBackgroundDark,
    Color OverlayBackgroundLight,
    Color OverlayTextDark,
    Color OverlayTextLight,
    Color OnBackgroundTextLight,
    Color OnBackgroundTextDark,
    bool InvertInDarkMode)
{
    public static BlinkTheme[] AllLight => [Peach, Sage, Sand, Midnight, Mono];
    public static BlinkTheme[] AllDark => [Midnight, Mono, Sage, Sand, Peach];
    public static BlinkTheme[] All => AllLight;

    public static BlinkTheme Named(string id) =>
        All.FirstOrDefault(t => t.Id == id) ?? Peach;

    public Color OverlayBackground(bool isDark) => isDark ? OverlayBackgroundDark : OverlayBackgroundLight;
    public Color OverlayText(bool isDark) => isDark ? OverlayTextDark : OverlayTextLight;
    public Color OnBackgroundText(bool isDark) => isDark ? OnBackgroundTextDark : OnBackgroundTextLight;

    public Color BackgroundTop(bool isDark) =>
        InvertInDarkMode && isDark ? C(0x1A, 0x1A, 0x1A) : BackgroundTopLight;
    public Color BackgroundBottom(bool isDark) =>
        InvertInDarkMode && isDark ? C(0x11, 0x11, 0x11) : BackgroundBottomLight;
    public Color Accent(bool isDark) =>
        InvertInDarkMode && isDark ? Colors.White : AccentLight;

    /// <summary>
    /// Text color for content on an accent-colored background.
    /// Returns black when accent resolves to white (Dark theme, Mono in dark mode), white otherwise.
    /// </summary>
    public Color TextOnAccent(bool isDark)
    {
        if (Id == "dark" || (InvertInDarkMode && isDark)) return C(0x00, 0x00, 0x00);
        return Colors.White;
    }

    private static Color C(byte r, byte g, byte b) => Color.FromArgb(255, r, g, b);

    // ── Themes ──

    /// <summary>Pure dark theme — used when "Use dark overlay" is enabled.</summary>
    public static readonly BlinkTheme Dark = new(
        "dark", "Dark",
        C(0x00, 0x00, 0x00), C(0x00, 0x00, 0x00), Colors.White,
        Color.FromArgb(242, 0x00, 0x00, 0x00), Color.FromArgb(242, 0x00, 0x00, 0x00),
        Colors.White, Colors.White,
        Colors.White, Colors.White, false);

    public static readonly BlinkTheme Peach = new(
        "peach", "Peach",
        C(0xFF, 0xB8, 0x9A), C(0xF0, 0x90, 0x60), C(0xE8, 0x85, 0x65),
        Color.FromArgb(235, 0x1A, 0x0E, 0x08), Color.FromArgb(242, 0xFF, 0xF0, 0xE8),
        C(0xFF, 0xDD, 0xCC), C(0x3D, 0x20, 0x12),
        Colors.White, Colors.White, false);

    public static readonly BlinkTheme Midnight = new(
        "midnight", "Midnight",
        C(0x2B, 0x2D, 0x52), C(0x1A, 0x1B, 0x3A), C(0x6B, 0x7D, 0xB5),
        Color.FromArgb(242, 0x0C, 0x0C, 0x1A), Color.FromArgb(242, 0xE8, 0xEA, 0xF4),
        C(0xB8, 0xC0, 0xE0), C(0x1A, 0x1B, 0x3A),
        Colors.White, Colors.White, false);

    public static readonly BlinkTheme Sage = new(
        "sage", "Sage",
        C(0xB8, 0xD4, 0xBC), C(0x7B, 0xAF, 0x8A), C(0x6E, 0xA8, 0x7E),
        Color.FromArgb(235, 0x0A, 0x1A, 0x0E), Color.FromArgb(242, 0xEA, 0xF5, 0xEC),
        C(0xC8, 0xEE, 0xD0), C(0x1A, 0x35, 0x20),
        Colors.White, Colors.White, false);

    public static readonly BlinkTheme Sand = new(
        "sand", "Sand",
        C(0xD8, 0xD0, 0xB8), C(0xB5, 0xAC, 0x8E), C(0x9A, 0x94, 0x78),
        Color.FromArgb(235, 0x14, 0x12, 0x0C), Color.FromArgb(242, 0xF2, 0xF0, 0xE8),
        C(0xE8, 0xE0, 0xCC), C(0x2E, 0x2A, 0x1E),
        Colors.White, Colors.White, false);

    public static readonly BlinkTheme Mono = new(
        "mono", "Mono",
        C(0xF5, 0xF5, 0xF5), C(0xE8, 0xE8, 0xE8), C(0x22, 0x22, 0x22),
        Color.FromArgb(242, 0x0A, 0x0A, 0x0A), Color.FromArgb(250, 0xFA, 0xFA, 0xFA),
        C(0xF0, 0xF0, 0xF0), C(0x1A, 0x1A, 0x1A),
        C(0x1A, 0x1A, 0x1A), Colors.White, true);
}
