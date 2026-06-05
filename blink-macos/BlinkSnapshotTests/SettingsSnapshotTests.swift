import XCTest
import SwiftUI
@testable import Blink

final class BreakSuggestionsHelpSnapshotTests: SnapshotTestCase {
    @MainActor func testHelpSheet() {
        for v in [
            ThemeVariant(name: "peach", theme: .peach, colorScheme: .light),
            ThemeVariant(name: "midnight", theme: .midnight, colorScheme: .dark),
        ] {
            assertSnapshot(
                of: BreakSuggestionsHelpView(theme: v.theme, onClose: {}),
                named: "break_suggestions_help_\(v.snapshotName)",
                width: 540, height: 640,
                colorScheme: v.colorScheme
            )
        }
    }
}

final class SettingsSnapshotTests: SnapshotTestCase {
    @MainActor func testSettings() {
        let themes: [(String, BlinkTheme)] = [
            ("peach", .peach), ("midnight", .midnight), ("sage", .sage),
            ("sand", .sand), ("mono", .mono),
        ]
        for (name, theme) in themes {
            for cs in [ColorScheme.light, .dark] {
                let label = "\(name)_\(cs == .dark ? "dark" : "light")"
                assertSnapshot(
                    of: SettingsView(appState: AppState(preview: true))
                        .environmentObject(ThemeManager.preview(theme)),
                    named: "settings_\(label)",
                    width: 440, height: 440,
                    colorScheme: cs
                )
            }
        }
    }
}
