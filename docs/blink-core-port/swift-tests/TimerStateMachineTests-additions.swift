// ADDITIONS to Tests/BlinkCoreTests/TimerStateMachineTests.swift.
// Drop these methods into the existing test class in the private blink-core repo.
//
// IMPORTANT — also fix the Swift TimerStateMachine the same way the C# version
// was fixed in commit 1900c25:
//
//     // Before — bug:
//     public var timerDuration: Double { Self.defaultDuration }
//
//     public func reset(_ duration: Double) {
//         remainingSeconds = duration
//         isPaused = false
//     }
//
//     // After — fix:
//     public private(set) var timerDuration: Double = Self.defaultDuration
//
//     public func reset(_ duration: Double) {
//         remainingSeconds = duration
//         timerDuration = duration
//         isPaused = false
//     }
//
//     public func resetAfterBreak() {
//         remainingSeconds = Self.defaultDuration
//         timerDuration = Self.defaultDuration
//         isPaused = false
//     }
//
// And update `progress` to divide by `timerDuration` instead of `defaultDuration`.
//
// Symptom: BlinkEngine.handleBreakDue calls timer.reset(10 * 60) for an
// extension, then fires onTimerUpdate(remaining=600, total=timerDuration). If
// timerDuration is stuck at 1200, a progress bar will render at 50% on a fresh
// extension instead of 0%.

import XCTest
@testable import BlinkCore

extension TimerStateMachineTests {

    func test_reset_toCustomDuration_updatesBothRemainingAndTimerDuration() {
        let timer = TimerStateMachine()
        timer.reset(600)
        XCTAssertEqual(timer.remainingSeconds, 600)
        XCTAssertEqual(timer.timerDuration, 600)
        XCTAssertEqual(timer.progress, 0.0)
        XCTAssertFalse(timer.isPaused)
    }

    func test_reset_progressStartsAtZero() {
        // Direct regression test — make sure a fresh extension shows 0% progress,
        // not (1 - 600/1200) = 50%.
        let timer = TimerStateMachine()
        timer.tick(.normal, deltaSeconds: 300) // burn 5 min of the original 20
        XCTAssertGreaterThan(timer.progress, 0)

        timer.reset(600) // extension to 10 min
        XCTAssertEqual(timer.progress, 0.0)
    }

    func test_resetAfterBreak_restoresDefault20Min() {
        let timer = TimerStateMachine()
        timer.reset(300)
        XCTAssertEqual(timer.remainingSeconds, 300)
        timer.resetAfterBreak()
        XCTAssertEqual(timer.remainingSeconds, 1200)
        XCTAssertEqual(timer.timerDuration, 1200)
    }

    func test_onBreakDue_notRefired_afterReset() {
        let timer = TimerStateMachine()
        var count = 0
        timer.onBreakDue = { count += 1 }
        timer.tick(.normal, deltaSeconds: 1200)
        XCTAssertEqual(count, 1)

        timer.resetAfterBreak()
        timer.tick(.normal, deltaSeconds: 1200)
        XCTAssertEqual(count, 2) // a fresh cycle is allowed to fire again
    }

    func test_isPaused_falseAfterMeetingEnds() {
        let timer = TimerStateMachine()
        timer.tick(.meeting, deltaSeconds: 1)
        XCTAssertTrue(timer.isPaused)
        timer.tick(.normal, deltaSeconds: 1)
        XCTAssertFalse(timer.isPaused)
    }

    func test_timerDuration_neverChanges_duringNormalCountdown() {
        // After the BlinkCore refactor, duration is fixed at 20 min — flow
        // doesn't extend it through the timer; BreakDecisionEngine handles extensions.
        let timer = TimerStateMachine()
        XCTAssertEqual(timer.timerDuration, 1200)
        timer.tick(.normal, deltaSeconds: 300)
        XCTAssertEqual(timer.timerDuration, 1200)
        timer.tick(.flow, deltaSeconds: 0)
        XCTAssertEqual(timer.timerDuration, 1200)
    }
}
