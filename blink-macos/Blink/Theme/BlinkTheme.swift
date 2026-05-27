import SwiftUI

struct BlinkTheme: Identifiable, Equatable {
    let id: String
    let name: String
    let iconAsset: String
    let menuBarIconAsset: String
    let backgroundTop: Color
    let backgroundBottom: Color
    /// Dark-mode tinted gradient — used for the fullscreen break overlay in dark mode.
    let backgroundTopDark: Color
    let backgroundBottomDark: Color
    let accent: Color
    let overlayBackgroundDark: Color
    let overlayBackgroundLight: Color
    let overlayTextDark: Color
    let overlayTextLight: Color

    /// Primary text color on the theme's background (onboarding, etc.)
    let onBackgroundTextLight: Color
    let onBackgroundTextDark: Color

    /// Whether the accent color should invert to white in dark mode (Mono only)
    let invertInDarkMode: Bool

    func onBackgroundText(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? onBackgroundTextDark : onBackgroundTextLight
    }

    func backgroundTop(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? backgroundTopDark : backgroundTop
    }

    func backgroundBottom(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? backgroundBottomDark : backgroundBottom
    }

    func backgroundGradient(for colorScheme: ColorScheme) -> LinearGradient {
        LinearGradient(
            colors: [backgroundTop(for: colorScheme), backgroundBottom(for: colorScheme)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    func accent(for colorScheme: ColorScheme) -> Color {
        guard invertInDarkMode && colorScheme == .dark else { return accent }
        return .white
    }

    /// Text color for content displayed on an accent-colored background.
    /// Returns black when accent resolves to white (Dark theme, Mono in dark mode),
    /// white for all other themes.
    func textOnAccent(for colorScheme: ColorScheme) -> Color {
        if id == "dark" || (invertInDarkMode && colorScheme == .dark) {
            return .black
        }
        return .white
    }

    /// System-aware overlay background
    func overlayBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? overlayBackgroundDark : overlayBackgroundLight
    }

    /// System-aware overlay text
    func overlayText(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? overlayTextDark : overlayTextLight
    }

    var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: [backgroundTop, backgroundBottom],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static let allLight: [BlinkTheme] = [.peach, .sage, .sand, .midnight, .mono]
    static let allDark: [BlinkTheme] = [.midnight, .mono, .sage, .sand, .peach]

    static var all: [BlinkTheme] { allLight }

    static func named(_ id: String) -> BlinkTheme {
        allLight.first { $0.id == id } ?? .peach
    }

    /// Pure dark overlay theme — used when "Use dark overlay" is on
    static let dark = BlinkTheme(
        id: "dark",
        name: "Dark",
        iconAsset: "AppIcon-Peach",
        menuBarIconAsset: "MenuBarIcon-Peach",
        backgroundTop: Color(hex: 0x000000),
        backgroundBottom: Color(hex: 0x000000),
        backgroundTopDark: Color(hex: 0x000000),
        backgroundBottomDark: Color(hex: 0x000000),
        accent: .white,
        overlayBackgroundDark: Color.black.opacity(0.95),
        overlayBackgroundLight: Color.black.opacity(0.95),
        overlayTextDark: .white,
        overlayTextLight: .white,
        onBackgroundTextLight: .white,
        onBackgroundTextDark: .white,
        invertInDarkMode: false
    )

    // MARK: - Themes

    static let peach = BlinkTheme(
        id: "peach",
        name: "Peach",
        iconAsset: "AppIcon-Peach",
        menuBarIconAsset: "MenuBarIcon-Peach",
        backgroundTop: Color(hex: 0xFFB89A),
        backgroundBottom: Color(hex: 0xF09060),
        backgroundTopDark: Color(hex: 0xA84A30),
        backgroundBottomDark: Color(hex: 0x6E2E1C),
        accent: Color(hex: 0xE88565),
        overlayBackgroundDark: Color(hex: 0x4A1F12).opacity(0.92),
        overlayBackgroundLight: Color(hex: 0xFFF0E8).opacity(0.95),
        overlayTextDark: Color(hex: 0xFFDDCC),
        overlayTextLight: Color(hex: 0x3D2012),
        // Light Peach background (0xFFB89A → 0xF09060) is too light for
        // white text — WCAG contrast is ~1.5:1, which reads as washed
        // out on the onboarding / permission pages and the rationale
        // sheet. Dark peach-brown matches the theme palette and pushes
        // contrast above legibility.
        onBackgroundTextLight: Color(hex: 0x3D2012),
        onBackgroundTextDark: .white,
        invertInDarkMode: false
    )

    static let midnight = BlinkTheme(
        id: "midnight",
        name: "Midnight",
        iconAsset: "AppIcon-Midnight",
        menuBarIconAsset: "MenuBarIcon-Midnight",
        backgroundTop: Color(hex: 0x2B2D52),
        backgroundBottom: Color(hex: 0x1A1B3A),
        backgroundTopDark: Color(hex: 0x14152C),
        backgroundBottomDark: Color(hex: 0x0A0B1A),
        accent: Color(hex: 0x6B7DB5),
        overlayBackgroundDark: Color(hex: 0x0C0C1A).opacity(0.95),
        overlayBackgroundLight: Color(hex: 0xE8EAF4).opacity(0.95),
        overlayTextDark: Color(hex: 0xB8C0E0),
        overlayTextLight: Color(hex: 0x1A1B3A),
        onBackgroundTextLight: .white,
        onBackgroundTextDark: .white,
        invertInDarkMode: false
    )

    static let sage = BlinkTheme(
        id: "sage",
        name: "Sage",
        iconAsset: "AppIcon-Sage",
        menuBarIconAsset: "MenuBarIcon-Sage",
        backgroundTop: Color(hex: 0xB8D4BC),
        backgroundBottom: Color(hex: 0x7BAF8A),
        backgroundTopDark: Color(hex: 0x1A2D20),
        backgroundBottomDark: Color(hex: 0x0E1A12),
        accent: Color(hex: 0x6EA87E),
        overlayBackgroundDark: Color(hex: 0x0A1A0E).opacity(0.92),
        overlayBackgroundLight: Color(hex: 0xEAF5EC).opacity(0.95),
        overlayTextDark: Color(hex: 0xC8EED0),
        overlayTextLight: Color(hex: 0x1A3520),
        // Light Sage background (0xB8D4BC) is too pastel for white text — WCAG
        // contrast lands at ~1.3:1. Dark forest green matches the theme palette
        // and keeps headings readable on the gradient.
        onBackgroundTextLight: Color(hex: 0x1A3520),
        onBackgroundTextDark: .white,
        invertInDarkMode: false
    )

    static let sand = BlinkTheme(
        id: "sand",
        name: "Sand",
        iconAsset: "AppIcon-Sand",
        menuBarIconAsset: "MenuBarIcon-Sand",
        backgroundTop: Color(hex: 0xD8D0B8),
        backgroundBottom: Color(hex: 0xB5AC8E),
        backgroundTopDark: Color(hex: 0x2A251A),
        backgroundBottomDark: Color(hex: 0x18160E),
        accent: Color(hex: 0x9A9478),
        overlayBackgroundDark: Color(hex: 0x14120C).opacity(0.92),
        overlayBackgroundLight: Color(hex: 0xF2F0E8).opacity(0.95),
        overlayTextDark: Color(hex: 0xE8E0CC),
        overlayTextLight: Color(hex: 0x2E2A1E),
        // Light Sand background (0xD8D0B8) is too pastel for white text — same
        // contrast failure as Sage. Dark brown stays inside the theme palette.
        onBackgroundTextLight: Color(hex: 0x2E2A1E),
        onBackgroundTextDark: .white,
        invertInDarkMode: false
    )

    static let mono = BlinkTheme(
        id: "mono",
        name: "Mono",
        iconAsset: "AppIcon-Mono",
        menuBarIconAsset: "MenuBarIcon-Mono",
        backgroundTop: Color(hex: 0xF5F5F5),
        backgroundBottom: Color(hex: 0xE8E8E8),
        backgroundTopDark: Color(hex: 0x1A1A1A),
        backgroundBottomDark: Color(hex: 0x111111),
        accent: Color(hex: 0x222222),
        overlayBackgroundDark: Color(hex: 0x0A0A0A).opacity(0.95),
        overlayBackgroundLight: Color(hex: 0xFAFAFA).opacity(0.98),
        overlayTextDark: Color(hex: 0xF0F0F0),
        overlayTextLight: Color(hex: 0x1A1A1A),
        onBackgroundTextLight: Color(hex: 0x1A1A1A),
        onBackgroundTextDark: .white,
        invertInDarkMode: true
    )
}

// MARK: - Hex color helper

extension Color {
    init(hex: UInt, alpha: Double = 1.0) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: alpha
        )
    }
}
