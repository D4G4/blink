import XCTest
import SwiftUI
@testable import Blink

final class ResearchSnapshotTests: SnapshotTestCase {
    @MainActor func testResearch() {
        let themes: [(String, BlinkTheme)] = [
            ("peach", .peach), ("midnight", .midnight), ("sage", .sage),
            ("sand", .sand), ("mono", .mono),
        ]
        for (name, theme) in themes {
            for cs in [ColorScheme.light, .dark] {
                let label = "\(name)_\(cs == .dark ? "dark" : "light")"
                assertSnapshot(
                    of: ResearchView(theme: theme, onDismiss: {}),
                    named: "research_\(label)",
                    width: 500, height: 700,
                    colorScheme: cs
                )
            }
        }
    }
}
