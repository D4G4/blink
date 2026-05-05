import SwiftUI

/// Manages the active theme with persistence.
final class ThemeManager: ObservableObject {
    static let shared = ThemeManager()

    @AppStorage("selectedTheme") private var selectedThemeID: String = "peach"
    @AppStorage("hasCompletedOnboarding") var hasCompletedOnboarding: Bool = false

    @Published var current: BlinkTheme

    private init() {
        let id = UserDefaults.standard.string(forKey: "selectedTheme") ?? "peach"
        self.current = BlinkTheme.named(id)
    }

    func select(_ theme: BlinkTheme) {
        selectedThemeID = theme.id
        current = theme
    }
}
