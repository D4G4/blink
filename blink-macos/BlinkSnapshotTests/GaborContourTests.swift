import XCTest
@testable import Blink

/// Logic guards for the contour-integration exercise (single-presentation
/// grouping task). The field renderer is verified visually; these pin the Δβ
/// staircase and the facing-scored response flow.
final class GaborContourTests: XCTestCase {

    // MARK: Δβ staircase

    func testStartsAtStartJitter() {
        let sc = ContourStaircase(start: 12, initialStep: 8)
        XCTAssertEqual(sc.jitterDeg, 12, accuracy: 0.001)
    }

    func testThreeCorrectRaisesJitterOneWrongLowersIt() {
        let sc = ContourStaircase(start: 20, initialStep: 8)
        sc.record(correct: true)
        sc.record(correct: true)
        XCTAssertEqual(sc.jitterDeg, 20, accuracy: 0.001, "no move before 3 correct")
        sc.record(correct: true)
        XCTAssertEqual(sc.jitterDeg, 28, accuracy: 0.001, "3 correct → harder (+8)")
        sc.record(correct: false)
        // up→down reversal: step halves 8→4, so 28 − 4 = 24
        XCTAssertEqual(sc.jitterDeg, 24, accuracy: 0.001, "1 wrong → easier, step halved at reversal")
    }

    func testJitterClampedToRange() {
        let sc = ContourStaircase(start: 2, initialStep: 8)
        sc.record(correct: false)                 // would go to -6, clamp at 0
        XCTAssertGreaterThanOrEqual(sc.jitterDeg, 0)
        let hi = ContourStaircase(start: 58, initialStep: 8)
        hi.record(correct: true); hi.record(correct: true); hi.record(correct: true)
        XCTAssertLessThanOrEqual(hi.jitterDeg, 60)
    }

    func testThresholdNilUntilSettledReversals() {
        let sc = ContourStaircase(start: 20, initialStep: 8)
        // Two reversals: not enough (needs > discard(2) + minSettled(4)).
        sc.record(correct: true); sc.record(correct: true); sc.record(correct: true) // up
        sc.record(correct: false)  // reversal 1
        sc.record(correct: true); sc.record(correct: true); sc.record(correct: true) // up: reversal 2
        XCTAssertNil(sc.threshold(), "too few settled reversals to report a threshold")
    }

    func testResetClearsState() {
        let sc = ContourStaircase(start: 20, initialStep: 8)
        sc.record(correct: true); sc.record(correct: true); sc.record(correct: true)
        sc.reset(start: 5)
        XCTAssertEqual(sc.jitterDeg, 5, accuracy: 0.001)
        XCTAssertEqual(sc.reversalCount, 0)
    }

    // MARK: Flow

    @MainActor func testStartExerciseSetsUpContourTrial() {
        let s = GaborExerciseState()
        s.exerciseType = .contour
        s.startExercise()
        XCTAssertEqual(s.currentTrial, 1)
        XCTAssertEqual(s.stage, .field, "contour opens on the field stage, not fixation")
        XCTAssertEqual(s.contourJitterRad, 0, accuracy: 0.0001, "warm-up starts at Δβ = 0")
    }

    @MainActor func testCorrectFacingScoresAndWrongDoesNot() {
        let hit = GaborExerciseState()
        hit.exerciseType = .contour
        hit.startExercise()
        hit.stage = .response
        hit.submitContourResponse(hit.contourFacing)
        XCTAssertEqual(hit.score, 1, "answering the actual facing scores")

        let miss = GaborExerciseState()
        miss.exerciseType = .contour
        miss.startExercise()
        miss.stage = .response
        miss.submitContourResponse(miss.contourFacing == .left ? .right : .left)
        XCTAssertEqual(miss.score, 0, "the opposite facing does not score")
    }

    @MainActor func testContourResponseIgnoredOutsideResponseStage() {
        let s = GaborExerciseState()
        s.exerciseType = .contour
        s.startExercise()   // stage == .field, not .response
        s.submitContourResponse(s.contourFacing)
        XCTAssertEqual(s.score, 0, "a response before the .response stage is ignored")
    }
}
