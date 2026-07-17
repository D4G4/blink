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

    /// Instructions for the primary detection exercise (contour's and crowding's
    /// demos render asynchronously, so they aren't deterministic static snapshots).
    @MainActor func testGaborInstructions() {
        let s = GaborExerciseState()
        s.exerciseType = .detection
        s.phase = .instructions
        assertHostedSnapshot(
            of: GaborExerciseView(state: s, theme: .peach, onDismiss: {}),
            named: "gabor_instructions_detection",
            width: 900, height: 1100,
            colorScheme: .dark
        )
    }

    /// The contour trial (a pre-rendered field injected so the async path is
    /// bypassed — a deterministic snapshot of the real ContourTrialView).
    @MainActor func testGaborContourTrial() {
        let W: CGFloat = 900, H: CGFloat = 700
        let fieldPt = min(W, H) * 0.86
        guard let cg = ContourFieldRenderer.render(sizePt: fieldPt, scale: 2, jitterRadians: 0,
                                                   facing: .right, seed: 5) else { return XCTFail("render") }
        let field = ContourField(image: cg, facing: .right, sizePt: fieldPt)
        let s = GaborExerciseState()
        s.exerciseType = .contour; s.currentTrial = 8; s.contourSeed = 1
        s.phase = .presenting; s.stage = .field
        assertSnapshot(
            of: ZStack { Color(white: GaborDisplayConfig.meanLuminanceGray)
                         ContourTrialView(state: s, theme: .peach, previewField: field) },
            named: "gabor_contour_trial", width: W, height: H, colorScheme: .light)
    }

    /// The crowding trial for both sides — the target flashes LEFT or RIGHT of
    /// the (prominent) fixation cross. Injected triplet → deterministic.
    @MainActor func testGaborCrowdingTrial() {
        let W: CGFloat = 900, H: CGFloat = 700
        let sz = min(max(0.08 * min(W, H), 56), 140)
        let E = min(4 * sz, (0.5 * W - sz) / 1.8)
        let spacing = 0.8 * E
        for (side, name) in [(CrowdingSide.left, "left"), (CrowdingSide.right, "right")] {
            guard let stim = CrowdingRenderer.render(patchPt: sz, spacingPt: spacing, tiltSign: 1,
                    flankerA: 1.0, flankerB: -0.5, flankers: true, scale: 2) else { return XCTFail("render") }
            let s = GaborExerciseState()
            s.exerciseType = .crowding; s.currentTrial = 8; s.crowdingSide = side; s.crowdingB = 0.8
            s.phase = .presenting; s.stage = .interval(1)
            assertSnapshot(
                of: ZStack { Color(white: GaborDisplayConfig.meanLuminanceGray)
                             CrowdingTrialView(state: s, theme: .peach, previewStimulus: stim) },
                named: "gabor_crowding_\(name)", width: W, height: H, colorScheme: .light)
        }
    }
}
