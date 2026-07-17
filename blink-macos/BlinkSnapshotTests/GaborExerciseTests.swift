import XCTest
@testable import Blink

// MARK: - Adaptive staircase

final class AdaptiveStaircaseTests: XCTestCase {

    func testStartsAtStartContrast() {
        XCTAssertEqual(AdaptiveStaircase(startContrast: 0.42).currentContrast, 0.42, accuracy: 1e-9)
    }

    func testStepsDownOnlyAfterThreeCorrect() {
        let s = AdaptiveStaircase(startContrast: 0.5, initialLogStep: 0.1)
        let c0 = s.currentContrast
        s.recordResponse(correct: true)
        XCTAssertEqual(s.currentContrast, c0, accuracy: 1e-9, "no move after 1 correct")
        s.recordResponse(correct: true)
        XCTAssertEqual(s.currentContrast, c0, accuracy: 1e-9, "no move after 2 correct")
        s.recordResponse(correct: true)
        // 3 correct → one multiplicative step down (×10^-0.1).
        XCTAssertEqual(s.currentContrast, c0 * pow(10, -0.1), accuracy: 1e-6)
    }

    func testStepsUpAfterSingleMiss() {
        let s = AdaptiveStaircase(startContrast: 0.3, initialLogStep: 0.1)
        let c0 = s.currentContrast
        s.recordResponse(correct: false)
        XCTAssertEqual(s.currentContrast, c0 * pow(10, 0.1), accuracy: 1e-6)
    }

    func testMissResetsTheCorrectRun() {
        let s = AdaptiveStaircase(startContrast: 0.5, initialLogStep: 0.1)
        s.recordResponse(correct: true)
        s.recordResponse(correct: true)
        s.recordResponse(correct: false)          // resets run + steps up
        let c = s.currentContrast
        s.recordResponse(correct: true)
        s.recordResponse(correct: true)           // only 2 in a row again
        XCTAssertEqual(s.currentContrast, c, accuracy: 1e-9, "must not step down until 3 in a row")
    }

    func testReversalsRecordedOnDirectionChange() {
        let s = AdaptiveStaircase(startContrast: 0.5, initialLogStep: 0.1)
        XCTAssertEqual(s.reversalCount, 0)
        s.recordResponse(correct: true); s.recordResponse(correct: true); s.recordResponse(correct: true) // down
        XCTAssertEqual(s.reversalCount, 0, "first move sets no reversal")
        s.recordResponse(correct: false)          // up → direction change → 1 reversal
        XCTAssertEqual(s.reversalCount, 1)
    }

    func testThresholdNilUntilTwoReversalsThenInRange() {
        let s = AdaptiveStaircase(startContrast: 0.5, initialLogStep: 0.1)
        XCTAssertNil(s.threshold())
        // Oscillate to accrue several reversals.
        for _ in 0..<8 {
            s.recordResponse(correct: true); s.recordResponse(correct: true); s.recordResponse(correct: true)
            s.recordResponse(correct: false)
        }
        let t = s.threshold()
        XCTAssertNotNil(t)
        // Geometric mean of reversal contrasts must sit inside the legal range.
        XCTAssertGreaterThan(t!, 0)
        XCTAssertLessThanOrEqual(t!, 1)
    }

    func testResetClampsStartContrast() {
        let s = AdaptiveStaircase()
        s.reset(startContrast: 5.0)
        XCTAssertLessThanOrEqual(s.currentContrast, 1.0)
        s.reset(startContrast: -1.0)
        XCTAssertGreaterThanOrEqual(s.currentContrast, 0.005)
    }

    func testNeverGoesBelowMinContrast() {
        let s = AdaptiveStaircase(startContrast: 0.02, initialLogStep: 0.5)
        for _ in 0..<60 { s.recordResponse(correct: true) }   // relentless down
        XCTAssertGreaterThanOrEqual(s.currentContrast, 0.005)
    }
}

// MARK: - Exercise flow

final class GaborExerciseStateTests: XCTestCase {

    @MainActor private func makeState(trials: Int = 5) -> GaborExerciseState {
        let s = GaborExerciseState(totalTrials: trials)
        s.phase = .ready                 // bypass the disclaimer gate
        return s
    }

    @MainActor func testStartExerciseGeneratesFirstTrial() {
        let s = makeState()
        s.startExercise()
        XCTAssertEqual(s.currentTrial, 1)
        XCTAssertEqual(s.score, 0)
        guard case .presenting = s.phase else { return XCTFail("should be presenting") }
        XCTAssertTrue((1...2).contains(s.targetInterval))
        XCTAssertTrue(GaborExerciseState.trainingSFs.contains(s.sessionSF))
        s.returnToPicker()
    }

    /// The invariant behind the "both flashes show a pattern" bug: exactly one
    /// interval holds the target, the other is blank.
    @MainActor func testExactlyOneIntervalHoldsTheTarget() {
        let s = makeState()
        s.startExercise()
        XCTAssertNotEqual(s.isTargetInterval(1), s.isTargetInterval(2),
                          "exactly one flash must hold the pattern")
        s.returnToPicker()
    }

    @MainActor func testCorrectAnswerScores() {
        let s = makeState()
        s.startExercise()
        s.stage = .response                          // synchronous: task can't interleave
        s.submitResponse(s.targetInterval)
        XCTAssertEqual(s.score, 1)
        XCTAssertEqual(s.accuracyPercent, 100)
        s.returnToPicker()
    }

    @MainActor func testWrongAnswerDoesNotScore() {
        let s = makeState()
        s.startExercise()
        s.stage = .response
        s.submitResponse(s.targetInterval == 1 ? 2 : 1)
        XCTAssertEqual(s.score, 0)
        s.returnToPicker()
    }

    @MainActor func testResponseIgnoredOutsideResponseStage() {
        let s = makeState()
        s.startExercise()
        s.stage = .fixation
        s.submitResponse(s.targetInterval)
        XCTAssertEqual(s.score, 0, "a response before the .response stage must be ignored")
        s.returnToPicker()
    }

    @MainActor func testReturnToPickerResets() {
        let s = makeState()
        s.startExercise()
        s.returnToPicker()
        XCTAssertEqual(s.currentTrial, 0)
        XCTAssertEqual(s.score, 0)
        guard case .ready = s.phase else { return XCTFail("should return to picker") }
    }

    @MainActor func testSpatialFrequencyRotatesBetweenSessions() {
        UserDefaults.standard.removeObject(forKey: "gaborSFRotation")
        var seen: [Double] = []
        for _ in 0..<GaborExerciseState.trainingSFs.count {
            let s = makeState(); s.startExercise(); seen.append(s.sessionSF); s.returnToPicker()
        }
        XCTAssertEqual(seen, GaborExerciseState.trainingSFs, "each session rotates to the next SF")
    }

    /// Guards against the backward mask returning to the default flow (the
    /// change that made both flashes look identical) and confirms the timed
    /// sequence actually reaches the response stage.
    @MainActor func testTimedSequenceReachesResponseAndShowsNoMask() async throws {
        let s = makeState()
        s.startExercise()
        var sawMask = false
        let deadline = Date().addingTimeInterval(3.0)
        while Date() < deadline {
            if case .mask = s.stage { sawMask = true }
            if case .response = s.stage { break }
            try await Task.sleep(for: .milliseconds(15))
        }
        XCTAssertFalse(sawMask, "the default flow must not present a backward mask")
        XCTAssertEqual(s.stage, .response, "the sequence must reach the response stage")
        s.returnToPicker()
    }
}
