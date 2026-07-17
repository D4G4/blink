import XCTest
@testable import Blink

/// Logic guards for the crowding exercise (single-look peripheral tilt-ID). The
/// triplet renderer is verified visually; these pin the flow + the b staircase.
final class GaborCrowdingTests: XCTestCase {

    // MARK: b staircase (reused AdaptiveStaircase with injected bounds)

    func testBStaircaseClampedToBounds() {
        let sc = AdaptiveStaircase(startContrast: 0.8, initialLogStep: 0.12,
                                   minContrast: 0.15, maxContrast: 1.0)
        // Drive it down (harder) many times: 3-correct steps only.
        for _ in 0..<40 { sc.recordResponse(correct: true) }
        XCTAssertGreaterThanOrEqual(sc.currentContrast, 0.15 - 1e-9, "b must not go below its floor")
        // Drive it up.
        for _ in 0..<40 { sc.recordResponse(correct: false) }
        XCTAssertLessThanOrEqual(sc.currentContrast, 1.0 + 1e-9, "b must not exceed its ceiling")
    }

    func testBStartsAtStart() {
        let sc = AdaptiveStaircase(startContrast: 0.8, minContrast: 0.15, maxContrast: 1.0)
        XCTAssertEqual(sc.currentContrast, 0.8, accuracy: 1e-9)
    }

    // MARK: Flow

    @MainActor func testStartExerciseSetsUpCrowdingTrial() {
        let s = GaborExerciseState()
        s.exerciseType = .crowding
        s.startExercise()
        XCTAssertEqual(s.currentTrial, 1)
        XCTAssertEqual(s.stage, .fixation, "crowding opens on fixation (single-look)")
        XCTAssertEqual(s.crowdingB, 0.8, accuracy: 1e-9, "starts uncrowded")
        XCTAssertFalse(s.showsSpatialFrequency, "crowding has no SF row")
    }

    @MainActor func testCorrectTiltScoresWrongDoesNot() {
        let hit = GaborExerciseState()
        hit.exerciseType = .crowding
        hit.startExercise()
        hit.crowdingIsCatch = false
        hit.stage = .response
        hit.submitTilt(hit.crowdingTiltSign)
        XCTAssertEqual(hit.score, 1, "the actual tilt scores")

        let miss = GaborExerciseState()
        miss.exerciseType = .crowding
        miss.startExercise()
        miss.crowdingIsCatch = false
        miss.stage = .response
        miss.submitTilt(-miss.crowdingTiltSign)
        XCTAssertEqual(miss.score, 0, "the opposite tilt does not score")
    }

    @MainActor func testCatchTrialDoesNotDriveStaircase() {
        let s = GaborExerciseState()
        s.exerciseType = .crowding
        s.startExercise()
        s.crowdingIsCatch = true
        s.stage = .response
        s.submitTilt(s.crowdingTiltSign)               // correct, but a catch trial
        XCTAssertEqual(s.score, 1, "catch trials still score")
        XCTAssertEqual(s.crowdingStaircase.trialResults.count, 0,
                       "catch (unflanked) trials must not update the b staircase")
    }

    @MainActor func testTiltIgnoredBeforeResponseStage() {
        let s = GaborExerciseState()
        s.exerciseType = .crowding
        s.startExercise()                              // stage == .fixation
        s.submitTilt(s.crowdingTiltSign)
        XCTAssertEqual(s.score, 0, "a response before the .response stage is ignored")
    }
}
