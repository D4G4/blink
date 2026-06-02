import XCTest
import SwiftUI
@testable import Blink

/// Snapshot coverage for the floating HUDs that had none: the Simple-mode
/// announcement HUD (both styles), the launch HUD, and the menu bar help view.
///
/// (The custom update-available HUD was removed in the v5.0.0 Sparkle
/// migration — Sparkle now owns update prompts — so there's nothing to snapshot
/// there.)
///
/// Matrix: peach + midnight × light + dark, plus per-HUD variants.
final class HUDSnapshotTests: SnapshotTestCase {
    private let themes: [(String, BlinkTheme)] = [("peach", .peach), ("midnight", .midnight)]
    private let schemes: [(String, ColorScheme)] = [("light", .light), ("dark", .dark)]

    @MainActor func testSimpleModeAnnouncementHUD() {
        let styles: [(String, SimpleModeAnnouncementView.Style)] = [
            ("announce", .announce), ("active", .activeByDefault),
        ]
        for (tn, theme) in themes {
            for (styleName, style) in styles {
                for (sn, cs) in schemes {
                    assertSnapshot(
                        of: SimpleModeAnnouncementView(theme: theme, style: style),
                        named: "simple_announcement_\(styleName)_\(tn)_\(sn)",
                        width: 400, height: 160, colorScheme: cs
                    )
                }
            }
        }
    }

    @MainActor func testLaunchHUD() {
        for (tn, theme) in themes {
            for (sn, cs) in schemes {
                assertSnapshot(
                    of: LaunchHUDView(theme: theme),
                    named: "launch_hud_\(tn)_\(sn)",
                    width: 380, height: 150, colorScheme: cs
                )
            }
        }
    }

    @MainActor func testMenuBarHelp() {
        for (tn, theme) in themes {
            for (sn, cs) in schemes {
                assertSnapshot(
                    of: MenuBarHelpView(theme: theme, onOpenPreferences: {}, onDismiss: {}),
                    named: "menu_bar_help_\(tn)_\(sn)",
                    width: 360, height: 440, colorScheme: cs
                )
            }
        }
    }
}
