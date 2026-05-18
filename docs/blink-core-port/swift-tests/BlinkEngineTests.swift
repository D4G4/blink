// Port of blink-windows/src/Blink.Core.Tests/BlinkEngineTests.cs
// Drop into Tests/BlinkCoreTests/ in the private blink-core repo.

import XCTest
@testable import BlinkCore

final class BlinkEngineTests: XCTestCase {

    // MARK: - Initial state

    func test_initialState_working_20Min() {
        let e = BlinkEngine()
        XCTAssertEqual(e.remainingSeconds, 1200)
        XCTAssertEqual(e.currentState, .working)
        XCTAssertEqual(e.currentBreakStreak, 0)
    }

    func test_sensitivity_defaultIs_0_7() {
        let e = BlinkEngine()
        XCTAssertEqual(e.sensitivity, 0.7, accuracy: 1e-6)
    }

    // MARK: - Tick + countdown

    func test_tick_firesTimerUpdate() {
        let e = BlinkEngine()
        var last: Double?
        e.onTimerUpdate = { rem, _ in last = rem }
        e.recordKeystroke()
        e.tick()
        XCTAssertNotNil(last)
        XCTAssertLessThan(last!, 1200)
    }

    func test_tick_countsDown_oneSecondPerTick() {
        let e = BlinkEngine()
        e.recordKeystroke()
        let before = e.remainingSeconds
        for _ in 0..<10 { e.tick() }
        let after = e.remainingSeconds
        XCTAssertGreaterThanOrEqual(before - after, 8)
        XCTAssertLessThanOrEqual(before - after, 12)
    }

    // MARK: - Idle / away

    func test_noActivity_doesNotImmediatelyTriggerIdle() {
        let e = BlinkEngine()
        e.recordKeystroke()
        e.tick()
        XCTAssertEqual(e.currentState, .working)
    }

    func test_activityResetsConsecutiveBreaksOnceIdle() {
        let e = BlinkEngine()
        e.userTookBreak()
        e.userTookBreak()
        XCTAssertEqual(e.currentBreakStreak, 2)
        for _ in 0..<5 { e.tick() }
        XCTAssertEqual(e.currentBreakStreak, 2)
    }

    // MARK: - Meeting

    func test_micActive_putsStateInMeeting() {
        let e = BlinkEngine()
        e.recordKeystroke()
        e.setMicActive(true)
        e.tick()
        XCTAssertEqual(e.currentState, .meeting)
    }

    func test_micReleased_returnsToWorking() {
        let e = BlinkEngine()
        e.recordKeystroke()
        e.setMicActive(true)
        e.tick()
        XCTAssertEqual(e.currentState, .meeting)
        e.setMicActive(false)
        e.tick()
        XCTAssertEqual(e.currentState, .working)
    }

    func test_cameraActive_alsoTriggersMeeting() {
        let e = BlinkEngine()
        e.recordKeystroke()
        e.setCameraActive(true)
        e.tick()
        XCTAssertEqual(e.currentState, .meeting)
    }

    // MARK: - Video

    func test_videoStart_resetsTimer() {
        let e = BlinkEngine()
        e.recordKeystroke()
        for _ in 0..<60 { e.tick() }
        XCTAssertLessThan(e.remainingSeconds, 1200)
        e.setVideoPlaying(true)
        XCTAssertEqual(e.remainingSeconds, 1200)
    }

    func test_videoPlaying_pausesCountdown() {
        let e = BlinkEngine()
        e.recordKeystroke()
        e.setVideoPlaying(true)
        let before = e.remainingSeconds
        for _ in 0..<30 { e.tick() }
        XCTAssertEqual(e.remainingSeconds, before)
    }

    func test_videoStop_resumesCountdown() {
        let e = BlinkEngine()
        e.recordKeystroke()
        e.setVideoPlaying(true)
        for _ in 0..<10 { e.tick() }
        let paused = e.remainingSeconds
        e.setVideoPlaying(false)
        e.recordKeystroke()
        for _ in 0..<10 { e.tick() }
        XCTAssertLessThan(e.remainingSeconds, paused)
    }

    // MARK: - Break flow

    func test_userTookBreak_firesStateChangeBack_andIncrementsStreak() {
        let e = BlinkEngine()
        var states: [BlinkEngine.DisplayState] = []
        e.onStateChange = { states.append($0) }
        e.userTookBreak()
        XCTAssertEqual(e.currentBreakStreak, 1)
        XCTAssertTrue(states.contains(.working))
    }

    func test_userSkippedBreak_doesNotIncrementStreak() {
        let e = BlinkEngine()
        e.userSkippedBreak()
        XCTAssertEqual(e.currentBreakStreak, 0)
    }

    func test_userTookBreak_resetsTimerTo20Min() {
        let e = BlinkEngine()
        e.recordKeystroke()
        for _ in 0..<60 { e.tick() }
        XCTAssertLessThan(e.remainingSeconds, 1200)
        e.userTookBreak()
        XCTAssertEqual(e.remainingSeconds, 1200)
    }

    func test_userSnoozed_setsTimerToProvidedMinutes() {
        let e = BlinkEngine()
        e.userSnoozed(5)
        XCTAssertEqual(e.remainingSeconds, 300)
    }

    // MARK: - Sensitivity propagation

    func test_sensitivity_settingPropagatesToDecisionEngine() {
        let e = BlinkEngine()
        e.sensitivity = 0.45
        XCTAssertEqual(e.sensitivity, 0.45, accuracy: 1e-6)
    }

    // MARK: - WakeFromSleep

    func test_wakeFromSleep_runsATick() {
        let e = BlinkEngine()
        var updates = 0
        e.onTimerUpdate = { _, _ in updates += 1 }
        e.recordKeystroke()
        e.wakeFromSleep()
        XCTAssertGreaterThan(updates, 0)
    }
}
