import XCTest
import SwiftUI
@testable import Blink

final class GaborExerciseSnapshotTests: SnapshotTestCase {
    @MainActor func testGaborExercise() {
        let themes: [(String, BlinkTheme)] = [
            ("peach", .peach), ("midnight", .midnight), ("sage", .sage),
            ("sand", .sand), ("mono", .mono),
        ]
        for (name, theme) in themes {
            for cs in [ColorScheme.light, .dark] {
                let label = "\(name)_\(cs == .dark ? "dark" : "light")"
                assertSnapshot(
                    of: GaborExerciseView(state: GaborExerciseState(), theme: theme, onDismiss: {}),
                    named: "gabor_exercise_\(label)",
                    width: 500, height: 400,
                    colorScheme: cs
                )
            }
        }
    }
}
