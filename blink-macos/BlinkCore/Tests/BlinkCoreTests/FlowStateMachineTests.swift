import Foundation
import Testing
@testable import BlinkCore

@Suite("FlowStateMachine")
struct FlowStateMachineTests {
    @Test("Starts in normal state")
    func initialState() {
        let sm = FlowStateMachine()
        #expect(sm.state == .normal)
    }

    // Helper: tick with standard parameters
    private func tick(
        _ sm: FlowStateMachine,
        idle: TimeInterval = 0,
        micActive: Bool = false,
        now: TimeInterval = 1000
    ) {
        sm.tick(
            flowScore: 0.5,
            secondsSinceLastInput: idle,
            isMicActive: micActive,
            isCameraActive: false,
            now: now
        )
    }

    // MARK: - Idle detection

    @Test("Idle detection triggers after 180s of no input")
    func idleDetection() {
        let sm = FlowStateMachine()
        tick(sm, idle: 25, now: 1000)
        #expect(sm.state == .normal, "25s idle should not trigger idle state")

        tick(sm, idle: 95, now: 1030)
        #expect(sm.state == .normal, "95s idle should not trigger idle state")

        tick(sm, idle: 185, now: 1060)
        #expect(sm.state == .idle)
    }

    @Test("Returns to normal after idle resumes")
    func returnFromIdle() {
        let sm = FlowStateMachine()
        tick(sm, idle: 185, now: 1000)
        #expect(sm.state == .idle)

        tick(sm, idle: 0, now: 1030)
        #expect(sm.state == .normal, "Should return to normal after input resumes")
    }

    // MARK: - Meeting detection

    @Test("Meeting detection when mic is active")
    func meetingDetection() {
        let sm = FlowStateMachine()
        tick(sm, micActive: true, now: 1000)
        #expect(sm.state == .meeting)
    }

    @Test("Returns to normal after meeting ends")
    func returnFromMeeting() {
        let sm = FlowStateMachine()
        tick(sm, micActive: true, now: 1000)
        #expect(sm.state == .meeting)

        tick(sm, micActive: false, now: 1030)
        #expect(sm.state == .normal, "Should return to normal when mic goes inactive")
    }

    // MARK: - Break prompted

    @Test("Enter and exit break prompted")
    func breakPrompted() {
        let sm = FlowStateMachine()
        sm.enterBreakPrompted()
        #expect(sm.state == .breakPrompted)

        sm.exitBreakPrompted()
        #expect(sm.state == .normal)
    }

    // MARK: - No continuous flow detection

    @Test("Continuous activity does NOT enter flow — flow detection is deferred to BreakDecisionEngine")
    func noFlowDetection() {
        let sm = FlowStateMachine()
        let baseTime: TimeInterval = 1000

        // 20 minutes of continuous activity
        for i in 0..<40 {
            tick(sm, idle: 3, now: baseTime + Double(i) * 30)
        }
        #expect(sm.state == .normal, "State machine should never enter flow — BreakDecisionEngine handles that")
    }

    // MARK: - State change callback

    @Test("onStateChange fires on transitions")
    func stateChangeCallback() {
        let sm = FlowStateMachine()
        var transitions: [(FlowState, FlowState)] = []
        sm.onStateChange = { old, new in transitions.append((old, new)) }

        tick(sm, idle: 185, now: 1000)  // → idle
        tick(sm, idle: 0, now: 1030)    // → normal
        tick(sm, micActive: true, now: 1060) // → meeting

        #expect(transitions.count == 3)
        #expect(transitions[0].1 == .idle)
        #expect(transitions[1].1 == .normal)
        #expect(transitions[2].1 == .meeting)
    }

    // MARK: - Config

    @Test("Max extensions scale with sensitivity")
    func maxExtensionsScaling() {
        let sm = FlowStateMachine()

        sm.sensitivity = 0.45  // Eye Health
        #expect(sm.config.maxExtensions == 0, "Eye Health → 0 extensions")

        sm.sensitivity = 0.65  // Balanced
        #expect(sm.config.maxExtensions == 1, "Balanced → 1 extension")

        sm.sensitivity = 0.85  // Deep Work
        #expect(sm.config.maxExtensions == 2, "Deep Work → 2 extensions")
    }
}
