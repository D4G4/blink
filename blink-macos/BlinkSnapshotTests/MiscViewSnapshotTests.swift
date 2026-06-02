import XCTest
import SwiftUI
@testable import Blink

/// Snapshot coverage for the small utility views that had none: the
/// keyboard-hint pill shown on the break overlay. (DebugToastView is a
/// `private` debug-only helper and isn't reachable from the test target.)
final class MiscViewSnapshotTests: SnapshotTestCase {
    @MainActor func testKeyHint() {
        for (tn, theme) in [("peach", BlinkTheme.peach), ("midnight", .midnight)] {
            for (sn, cs) in [("light", ColorScheme.light), ("dark", .dark)] {
                assertSnapshot(
                    of: KeyHintView(key: "esc", label: "Skip", theme: theme),
                    named: "key_hint_\(tn)_\(sn)",
                    width: 160, height: 90, colorScheme: cs
                )
            }
        }
    }
}
