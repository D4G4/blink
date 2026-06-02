import XCTest
import SwiftUI
@testable import Blink

/// Captures the menu bar's Simple-mode detection card, which the default
/// `MenuBarSnapshotTests` can't show: that test uses `AppState(preview: true)`,
/// which forces `hasInputMonitoringPermission = true` (Smart mode → no card).
///
/// Here we flip the flag off and drive both card variants via the
/// `basicModeOptIn` UserDefaults key the card reads:
///   - deliberate Simple (basicModeOptIn = true)
///   - missing/revoked IM (basicModeOptIn = false)
final class DetectionModeCardSnapshotTests: SnapshotTestCase {
    @MainActor func testSimpleModeCard() {
        let themes: [(String, BlinkTheme)] = [("peach", .peach), ("midnight", .midnight)]
        let states: [(String, Bool)] = [("deliberate", true), ("missing_im", false)]

        for (themeName, theme) in themes {
            for (stateName, basicOptIn) in states {
                UserDefaults.standard.set(basicOptIn, forKey: "basicModeOptIn")
                let state = AppState(preview: true)
                state.hasInputMonitoringPermission = false  // force the card to render

                for cs in [ColorScheme.light, .dark] {
                    let label = "\(themeName)_\(stateName)_\(cs == .dark ? "dark" : "light")"
                    assertSnapshot(
                        of: MenuBarView(appState: state)
                            .environmentObject(ThemeManager.preview(theme)),
                        named: "menu_bar_simple_\(label)",
                        width: 280, height: 350,
                        colorScheme: cs
                    )
                }
            }
        }

        // Leave the key cleared so it can't leak into other suites.
        UserDefaults.standard.set(false, forKey: "basicModeOptIn")
    }
}
