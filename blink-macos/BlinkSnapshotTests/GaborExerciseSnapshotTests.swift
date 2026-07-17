import XCTest
import SwiftUI
@testable import Blink

final class GaborExerciseSnapshotTests: SnapshotTestCase {

    // Patch size is now derived from the render size (screen-proportional), so
    // these snapshots are deterministic from the fixed width/height alone — no
    // display-config override needed.

    /// The exercise picker across every theme (light + dark).
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

    /// Every stage of a detection trial at the shipped window size — this is the
    /// visual regression baseline for the trial screen (clean field, centered
    /// stimulus, grouped answer prompt). Whole-screen, so a stray/off-center
    /// element or scattered chrome shows up as a diff.
    @MainActor func testGaborTrialStages() {
        let stages: [(String, (GaborExerciseState) -> Void)] = [
            ("fixation",         { $0.phase = .presenting; $0.stage = .fixation }),
            ("empty_flash",      { $0.phase = .presenting; $0.targetInterval = 2; $0.stage = .interval(1) }),
            ("pattern_flash",    { $0.phase = .presenting; $0.targetInterval = 2; $0.stage = .interval(2) }),
            ("gap",              { $0.phase = .presenting; $0.stage = .gap }),
            ("response",         { $0.phase = .presenting; $0.stage = .response }),
            ("feedback_correct", { $0.stage = .response; $0.phase = .feedback(correct: true) }),
            ("feedback_wrong",   { $0.stage = .response; $0.phase = .feedback(correct: false) }),
            ("complete",         { $0.phase = .complete }),
        ]
        for (name, cfg) in stages {
            let s = GaborExerciseState()
            s.currentTrial = 12; s.score = 8; s.sessionSF = 3; s.exerciseType = .detection
            cfg(s)
            assertSnapshot(
                of: GaborExerciseView(state: s, theme: .peach, onDismiss: {}),
                named: "gabor_trial_\(name)",
                width: 900, height: 700,
                colorScheme: .light
            )
        }
    }

    /// The in-app "The science" / sources screen (scrolls → hosted render).
    @MainActor func testGaborScience() {
        let s = GaborExerciseState()
        s.phase = .science
        assertHostedSnapshot(
            of: GaborExerciseView(state: s, theme: .peach, onDismiss: {}),
            named: "gabor_science",
            width: 900, height: 1080,
            colorScheme: .dark
        )
    }

    /// Instructions for the two shader-based exercises (contour's demo renders
    /// asynchronously, so it isn't a deterministic static snapshot).
    @MainActor func testGaborInstructions() {
        for type in [ExerciseType.detection, .flanker] {
            let s = GaborExerciseState()
            s.exerciseType = type
            s.phase = .instructions
            assertHostedSnapshot(
                of: GaborExerciseView(state: s, theme: .peach, onDismiss: {}),
                named: "gabor_instructions_\(type == .detection ? "detection" : "flanker")",
                width: 900, height: 1100,
                colorScheme: .dark
            )
        }
    }
}
