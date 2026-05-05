import SwiftUI

struct BlinkTheme: Identifiable, Equatable {
    let id: String
    let name: String
    let iconAsset: String
    let menuBarIconAsset: String
    let backgroundTop: Color
    let backgroundBottom: Color
    let accent: Color
    let overlayBackgroundDark: Color
    let overlayBackgroundLight: Color
    let overlayTextDark: Color
    let overlayTextLight: Color

    /// Primary text color on the theme's background (onboarding, etc.)
    let onBackgroundTextLight: Color
    let onBackgroundTextDark: Color

    /// Whether background colors should invert in dark mode
    let invertInDarkMode: Bool

    func onBackgroundText(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? onBackgroundTextDark : onBackgroundTextLight
    }

    func backgroundTop(for colorScheme: ColorScheme) -> Color {
        guard invertInDarkMode && colorScheme == .dark else { return backgroundTop }
        return Color(hex: 0x1A1A1A)
    }

    func backgroundBottom(for colorScheme: ColorScheme) -> Color {
        guard invertInDarkMode && colorScheme == .dark else { return backgroundBottom }
        return Color(hex: 0x111111)
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

    static let all: [BlinkTheme] = [
        .peach, .midnight, .sage, .sand, .mono
    ]

    static func named(_ id: String) -> BlinkTheme {
        all.first { $0.id == id } ?? .peach
    }

    /// Pure dark overlay theme — used when "Use dark overlay" is on
    static let dark = BlinkTheme(
        id: "dark",
        name: "Dark",
        iconAsset: "AppIcon-Peach",
        menuBarIconAsset: "MenuBarIcon-Peach",
        backgroundTop: Color(hex: 0x000000),
        backgroundBottom: Color(hex: 0x000000),
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
        accent: Color(hex: 0xE88565),
        overlayBackgroundDark: Color(hex: 0x1A0E08).opacity(0.92),
        overlayBackgroundLight: Color(hex: 0xFFF0E8).opacity(0.95),
        overlayTextDark: Color(hex: 0xFFDDCC),
        overlayTextLight: Color(hex: 0x3D2012),
        onBackgroundTextLight: .white,
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
        accent: Color(hex: 0x6EA87E),
        overlayBackgroundDark: Color(hex: 0x0A1A0E).opacity(0.92),
        overlayBackgroundLight: Color(hex: 0xEAF5EC).opacity(0.95),
        overlayTextDark: Color(hex: 0xC8EED0),
        overlayTextLight: Color(hex: 0x1A3520),
        onBackgroundTextLight: .white,
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
        accent: Color(hex: 0x9A9478),
        overlayBackgroundDark: Color(hex: 0x14120C).opacity(0.92),
        overlayBackgroundLight: Color(hex: 0xF2F0E8).opacity(0.95),
        overlayTextDark: Color(hex: 0xE8E0CC),
        overlayTextLight: Color(hex: 0x2E2A1E),
        onBackgroundTextLight: .white,
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
