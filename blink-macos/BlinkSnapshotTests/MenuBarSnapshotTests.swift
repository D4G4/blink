import XCTest
import SwiftUI
@testable import Blink

final class MenuBarSnapshotTests: SnapshotTestCase {
    /// The permission-attention row at the top of the menu, shown when an
    /// enabled Auto-Pause feature lost its OS permission.
    @MainActor func testMenuBarPermissionAttention() {
        for v in [
            ThemeVariant(name: "peach", theme: .peach, colorScheme: .light),
            ThemeVariant(name: "midnight", theme: .midnight, colorScheme: .dark),
        ] {
            let state = AppState(preview: true)
            state.setPermissionAlertsForPreview([.calendar])
            assertSnapshot(
                of: MenuBarView(appState: state)
                    .environmentObject(ThemeManager.preview(v.theme)),
                named: "menu_bar_permission_attention_\(v.snapshotName)",
                width: 280, height: 400,
                colorScheme: v.colorScheme
            )
        }
    }

    @MainActor func testMenuBar() {
        let themes: [(String, BlinkTheme)] = [
            ("peach", .peach), ("midnight", .midnight), ("sage", .sage),
            ("sand", .sand), ("mono", .mono),
        ]
        for (name, theme) in themes {
            for cs in [ColorScheme.light, .dark] {
                let label = "\(name)_\(cs == .dark ? "dark" : "light")"
                assertSnapshot(
                    of: MenuBarView(appState: AppState(preview: true))
                        .environmentObject(ThemeManager.preview(theme)),
                    named: "menu_bar_\(label)",
                    width: 280, height: 350,
                    colorScheme: cs
                )
            }
        }
    }

    /// Paused-state variants. The header control swaps to a one-tap Resume
    /// button, the "Take Break Now" CTA hides, and the state label reflects
    /// the pause reason. Only the two deterministic pause modes are snapshotted:
    ///   - `.indefinite`  → "Paused"
    ///   - `.currentApp`  → "Paused while <App> is open"
    /// `.timed` is intentionally excluded — its label embeds a wall-clock
    /// resume time that would differ every run and defeat pixel comparison.
    ///
    /// `pauseMode` is set directly (not via `pause(_:)`) so no monitors,
    /// overlays, or persistence are touched — it's pure render state, stable
    /// because preview `AppState` runs no tick loop to auto-resume it.
    @MainActor func testMenuBarPaused() {
        let themes: [(String, BlinkTheme)] = [
            ("peach", .peach), ("midnight", .midnight),
        ]
        let modes: [(String, PauseMode)] = [
            ("paused", .indefinite),
            ("paused_app", .currentApp(bundleID: "com.apple.dt.Xcode", name: "Xcode")),
        ]
        for (modeName, mode) in modes {
            for (name, theme) in themes {
                for cs in [ColorScheme.light, .dark] {
                    let state = AppState(preview: true)
                    state.pauseMode = mode
                    let label = "\(name)_\(cs == .dark ? "dark" : "light")"
                    assertSnapshot(
                        of: MenuBarView(appState: state)
                            .environmentObject(ThemeManager.preview(theme)),
                        named: "menu_bar_\(modeName)_\(label)",
                        width: 280, height: 350,
                        colorScheme: cs
                    )
                }
            }
        }
    }
}
