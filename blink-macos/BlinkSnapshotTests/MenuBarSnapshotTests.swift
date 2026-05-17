import XCTest
import SwiftUI
@testable import Blink

final class MenuBarSnapshotTests: SnapshotTestCase {
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
                        .environmentObject(ThemeManager.preview(theme))
                        .environmentObject(UpdateChecker.shared),
                    named: "menu_bar_\(label)",
                    width: 280, height: 350,
                    colorScheme: cs
                )
            }
        }
    }
}
