import XCTest
import SwiftUI
@testable import Blink

final class WhyExistSnapshotTests: SnapshotTestCase {
    @MainActor func testWhyExist() {
        let themes: [(String, BlinkTheme)] = [
            ("peach", .peach), ("midnight", .midnight), ("sage", .sage),
            ("sand", .sand), ("mono", .mono),
        ]
        for (name, theme) in themes {
            for cs in [ColorScheme.light, .dark] {
                let label = "\(name)_\(cs == .dark ? "dark" : "light")"
                assertSnapshot(
                    of: WhyExistView(theme: theme, onDismiss: {}),
                    named: "why_exist_\(label)",
                    width: 500, height: 420,
                    colorScheme: cs
                )
            }
        }
    }
}

final class FlowLearnMoreSnapshotTests: SnapshotTestCase {
    @MainActor func testFlowLearnMore() {
        let themes: [(String, BlinkTheme)] = [
            ("peach", .peach), ("midnight", .midnight), ("sage", .sage),
            ("sand", .sand), ("mono", .mono),
        ]
        for (name, theme) in themes {
            for cs in [ColorScheme.light, .dark] {
                let label = "\(name)_\(cs == .dark ? "dark" : "light")"
                assertSnapshot(
                    of: FlowLearnMoreView(theme: theme, onDismiss: {}),
                    named: "flow_learn_more_\(label)",
                    width: 500, height: 700,
                    colorScheme: cs
                )
            }
        }
    }
}
