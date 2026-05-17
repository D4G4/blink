import XCTest
import SwiftUI
@testable import Blink

final class FlowSensitivitySnapshotTests: SnapshotTestCase {
    @MainActor func testFlowSensitivitySettings() {
        let themes: [(String, BlinkTheme)] = [
            ("peach", .peach), ("midnight", .midnight), ("sage", .sage),
            ("sand", .sand), ("mono", .mono),
        ]
        for (name, theme) in themes {
            for cs in [ColorScheme.light, .dark] {
                let label = "\(name)_\(cs == .dark ? "dark" : "light")"
                let accent = cs == .dark && theme.invertInDarkMode ? Color.white : theme.accent
                assertSnapshot(
                    of: FlowSensitivityView(
                        sensitivity: .constant(0.65),
                        accentColor: accent,
                        foregroundColor: .primary,
                        style: .settings,
                        onResearchTapped: {},
                        onLearnMoreTapped: {}
                    ),
                    named: "flow_sensitivity_settings_\(label)",
                    width: 400, height: 300,
                    colorScheme: cs
                )
            }
        }
    }
}
