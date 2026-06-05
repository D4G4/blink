import XCTest
import SwiftUI
@testable import Blink

final class SmartSuggestionsSettingControlsSnapshotTests: SnapshotTestCase {
    /// Focused snapshot of the toggle + caption + Learn-more entry point
    /// the user added to General settings. Snapshotted as a standalone
    /// View because the SettingsView body wraps its content in a
    /// ScrollView that ImageRenderer doesn't measure — the full Settings
    /// snapshot renders blank below the tab bar, which is why this
    /// section needs its own coverage.
    @MainActor func testSmartSuggestionsSettingControls() {
        for v in [
            ThemeVariant(name: "peach", theme: .peach, colorScheme: .light),
            ThemeVariant(name: "midnight", theme: .midnight, colorScheme: .dark),
        ] {
            let accent = v.theme.accent(for: v.colorScheme)
            assertSnapshot(
                of: SmartSuggestionsSettingControls(
                    theme: v.theme,
                    accentColor: accent,
                    isOn: .constant(true),
                    showHelp: .constant(false)
                )
                .padding(20),
                named: "smart_suggestions_settings_\(v.snapshotName)",
                width: 440, height: 200,
                colorScheme: v.colorScheme
            )
        }
    }
}

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
                // SettingsView wraps its content in a ScrollView; ImageRenderer
                // doesn't measure that and the result is a blank tab bar.
                // assertHostedSnapshot routes through NSHostingView so the
                // ScrollView lays out properly. Tall frame (1200pt) so the
                // full General tab renders end-to-end and every iconified
                // row is visible without the snapshot needing to scroll.
                assertHostedSnapshot(
                    of: SettingsView(appState: AppState(preview: true))
                        .environmentObject(ThemeManager.preview(theme)),
                    named: "settings_\(label)",
                    width: 440, height: 1200,
                    colorScheme: cs
                )
            }
        }
    }
}
