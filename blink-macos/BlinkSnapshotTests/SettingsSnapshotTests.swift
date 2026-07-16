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
    /// The 10-day "What's New" card at the top of General (gated by
    /// AppState.recentlyUpdatedVersion). Forces the surfaced-version keys on
    /// so the card renders, then clears them.
    @MainActor func testWhatsNewCard() {
        let d = UserDefaults.standard
        let current = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        d.set(current, forKey: AppState.whatsNewSurfacedVersionKey)
        d.set(Date().timeIntervalSinceReferenceDate, forKey: AppState.whatsNewSurfacedDateKey)
        defer {
            d.removeObject(forKey: AppState.whatsNewSurfacedVersionKey)
            d.removeObject(forKey: AppState.whatsNewSurfacedDateKey)
        }
        for cs in [ColorScheme.light, .dark] {
            assertHostedSnapshot(
                of: SettingsView(appState: AppState(preview: true), category: .general)
                    .environmentObject(ThemeManager.preview(.peach)),
                named: "whatsnew_card_\(cs == .dark ? "dark" : "light")",
                width: 720, height: 780,
                colorScheme: cs
            )
        }
    }

    /// Every sidebar pane (System-Settings redesign), light + dark. This is
    /// the per-screen coverage — one snapshot per category so a layout
    /// regression in any pane is caught, not just the default General view.
    /// 720×760 matches the real prefs window (720×500) with headroom so each
    /// pane renders sidebar-and-all without the detail ScrollView clipping.
    @MainActor func testEveryPane() {
        for category in SettingsCategory.allCases {
            for cs in [ColorScheme.light, .dark] {
                let label = "\(String(describing: category))_\(cs == .dark ? "dark" : "light")"
                assertHostedSnapshot(
                    of: SettingsView(appState: AppState(preview: true), category: category)
                        .environmentObject(ThemeManager.preview(.peach)),
                    named: "pane_\(label)",
                    width: 720, height: 900,
                    colorScheme: cs
                )
            }
        }
    }

    /// Focus pane in Simple (Input-Monitoring-off) mode — a distinct layout
    /// from Smart: the sensitivity slider + Flow Check are replaced by the
    /// locked prompt. `testEveryPane` renders the Smart variant (preview
    /// hard-codes the permission on), so this covers the other branch.
    @MainActor func testFocusPaneLocked() {
        for cs in [ColorScheme.light, .dark] {
            let state = AppState(preview: true)
            state.hasInputMonitoringPermission = false
            assertHostedSnapshot(
                of: SettingsView(appState: state, category: .focus)
                    .environmentObject(ThemeManager.preview(.peach)),
                named: "pane_focus_locked_\(cs == .dark ? "dark" : "light")",
                width: 720, height: 900,
                colorScheme: cs
            )
        }
    }

    /// Theme breadth on the General pane — accent color, toggle styling, and
    /// the selected-theme ring differ per theme. Covers all 5 themes × both
    /// schemes so a theming regression is caught even though pane *layout* is
    /// theme-independent (and thus only needs one theme in `testEveryPane`).
    @MainActor func testGeneralAllThemes() {
        let themes: [(String, BlinkTheme)] = [
            ("peach", .peach), ("midnight", .midnight), ("sage", .sage),
            ("sand", .sand), ("mono", .mono),
        ]
        for (name, theme) in themes {
            for cs in [ColorScheme.light, .dark] {
                let label = "\(name)_\(cs == .dark ? "dark" : "light")"
                assertHostedSnapshot(
                    of: SettingsView(appState: AppState(preview: true))
                        .environmentObject(ThemeManager.preview(theme)),
                    named: "settings_\(label)",
                    width: 720, height: 800,
                    colorScheme: cs
                )
            }
        }
    }
}
