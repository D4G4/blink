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

    @Test("High score for 3+ minutes transitions to flow")
    func normalToFlow() {
        let sm = FlowStateMachine()
        let baseTime: TimeInterval = 1000

        // Tick every 30s with high score for 4 minutes (8 ticks)
        for i in 0..<8 {
            sm.tick(
                flowScore: 0.8,
                secondsSinceLastInput: 0,
                isMicActive: false,
                isCameraActive: false,
                now: baseTime + Double(i) * 30
            )
        }

        #expect(sm.state == .flow)
    }

    @Test("Score below threshold does not immediately exit flow")
    func flowHysteresis() {
        let sm = FlowStateMachine()
        let baseTime: TimeInterval = 1000

        // Enter flow (3+ minutes of high score)
        for i in 0..<8 {
            sm.tick(flowScore: 0.8, secondsSinceLastInput: 0,
                    isMicActive: false, isCameraActive: false,
                    now: baseTime + Double(i) * 30)
        }
        #expect(sm.state == .flow)

        // One tick of low score should NOT exit flow
        sm.tick(flowScore: 0.3, secondsSinceLastInput: 0,
                isMicActive: false, isCameraActive: false,
                now: baseTime + 270)
        #expect(sm.state == .flow, "Single low-score tick should not break flow")
    }

    @Test("Sustained low score exits flow after 2 minutes")
    func flowToNormal() {
        let sm = FlowStateMachine()
        let baseTime: TimeInterval = 1000

        // Enter flow
        for i in 0..<8 {
            sm.tick(flowScore: 0.8, secondsSinceLastInput: 0,
                    isMicActive: false, isCameraActive: false,
                    now: baseTime + Double(i) * 30)
        }
        #expect(sm.state == .flow)

        // 3 minutes of low score (6 ticks at 30s)
        let flowExitStart = baseTime + 240
        for i in 0..<6 {
            sm.tick(flowScore: 0.2, secondsSinceLastInput: 0,
                    isMicActive: false, isCameraActive: false,
                    now: flowExitStart + Double(i) * 30)
        }
        #expect(sm.state == .normal)
    }

    @Test("Idle detection triggers after 180s of no input")
    func idleDetection() {
        let sm = FlowStateMachine()
        // 25s is not enough — should stay normal
        sm.tick(flowScore: 0.5, secondsSinceLastInput: 25,
                isMicActive: false, isCameraActive: false, now: 1000)
        #expect(sm.state == .normal, "25s idle should not trigger idle state")

        // 95s should NOT trigger idle (threshold is 180s)
        sm.tick(flowScore: 0.5, secondsSinceLastInput: 95,
                isMicActive: false, isCameraActive: false, now: 1030)
        #expect(sm.state == .normal, "95s idle should not trigger idle state")

        // 185s should trigger idle
        sm.tick(flowScore: 0.5, secondsSinceLastInput: 185,
                isMicActive: false, isCameraActive: false, now: 1060)
        #expect(sm.state == .idle)
    }

    @Test("Meeting detection when mic is active")
    func meetingDetection() {
        let sm = FlowStateMachine()
        sm.tick(flowScore: 0.5, secondsSinceLastInput: 0,
                isMicActive: true, isCameraActive: false, now: 1000)
        #expect(sm.state == .meeting)
    }

    @Test("Returns to normal after idle, flow must be re-earned")
    func restoreAfterIdle() {
        let sm = FlowStateMachine()
        let baseTime: TimeInterval = 1000

        // Enter flow
        for i in 0..<8 {
            sm.tick(flowScore: 0.8, secondsSinceLastInput: 0,
                    isMicActive: false, isCameraActive: false,
                    now: baseTime + Double(i) * 30)
        }
        #expect(sm.state == .flow)

        // Go idle (180s+ no input)
        sm.tick(flowScore: 0.8, secondsSinceLastInput: 190,
                isMicActive: false, isCameraActive: false,
                now: baseTime + 300)
        #expect(sm.state == .idle)

        // Resume — should return to normal, NOT flow (flow must be re-earned)
        sm.tick(flowScore: 0.8, secondsSinceLastInput: 0,
                isMicActive: false, isCameraActive: false,
                now: baseTime + 330)
        #expect(sm.state == .normal, "After idle, should return to normal — flow must be re-earned")
    }

    @Test("15+ minutes in flow transitions to deep flow")
    func flowToDeepFlow() {
        let sm = FlowStateMachine()
        let baseTime: TimeInterval = 1000

        // 20 minutes of high score (40 ticks at 30s)
        for i in 0..<40 {
            sm.tick(flowScore: 0.8, secondsSinceLastInput: 0,
                    isMicActive: false, isCameraActive: false,
                    now: baseTime + Double(i) * 30)
        }
        #expect(sm.state == .deepFlow)
    }
}
