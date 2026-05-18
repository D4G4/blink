// ADDITIONS to Tests/BlinkCoreTests/FlowStateMachineTests.swift.
// Drop these methods into the existing test class in the private blink-core repo.

import XCTest
@testable import BlinkCore

extension FlowStateMachineTests {

    // MARK: - Idle boundary cases

    func test_idle_atExactly180s_triggersIdle() {
        let sm = FlowStateMachine()
        sm.tick(flowScore: 0, idleSeconds: 180, micActive: false, cameraActive: false, now: 1000)
        XCTAssertEqual(sm.state, .idle)
    }

    func test_idle_justBelow180s_staysNormal() {
        let sm = FlowStateMachine()
        sm.tick(flowScore: 0, idleSeconds: 179.9, micActive: false, cameraActive: false, now: 1000)
        XCTAssertEqual(sm.state, .normal)
    }

    // MARK: - Meeting via camera only

    func test_cameraOnly_triggersMeeting() {
        let sm = FlowStateMachine()
        sm.tick(flowScore: 0, idleSeconds: 0, micActive: false, cameraActive: true, now: 1000)
        XCTAssertEqual(sm.state, .meeting)
    }

    func test_micAndCamera_bothActive_staysInMeeting() {
        let sm = FlowStateMachine()
        sm.tick(flowScore: 0, idleSeconds: 0, micActive: true, cameraActive: true, now: 1000)
        XCTAssertEqual(sm.state, .meeting)

        sm.tick(flowScore: 0, idleSeconds: 0, micActive: false, cameraActive: true, now: 1030)
        XCTAssertEqual(sm.state, .meeting)

        sm.tick(flowScore: 0, idleSeconds: 0, micActive: true, cameraActive: false, now: 1060)
        XCTAssertEqual(sm.state, .meeting)

        sm.tick(flowScore: 0, idleSeconds: 0, micActive: false, cameraActive: false, now: 1090)
        XCTAssertEqual(sm.state, .normal)
    }

    // MARK: - Idle vs meeting precedence

    func test_idle_duringMeeting_staysInMeeting() {
        // User has mic on but isn't typing — they're still in the meeting,
        // so we don't pretend they walked away.
        let sm = FlowStateMachine()
        sm.tick(flowScore: 0, idleSeconds: 200, micActive: true, cameraActive: false, now: 1000)
        XCTAssertEqual(sm.state, .meeting)
    }

    // MARK: - Idempotency

    func test_repeatedTicks_withSameInputs_areIdempotent() {
        let sm = FlowStateMachine()
        sm.tick(flowScore: 0, idleSeconds: 200, micActive: false, cameraActive: false, now: 1000)
        XCTAssertEqual(sm.state, .idle)
        for i in 0..<10 {
            sm.tick(flowScore: 0, idleSeconds: 200, micActive: false, cameraActive: false, now: 1000 + Double(i))
        }
        XCTAssertEqual(sm.state, .idle)
    }
}
