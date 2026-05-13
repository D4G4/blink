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

    @Test("Continuous activity for 3+ minutes transitions to flow")
    func normalToFlow() {
        let sm = FlowStateMachine()
        let baseTime: TimeInterval = 1000

        // Tick every 30s with recent input (secondsSinceLastInput < gapTolerance)
        // Default sensitivity 0.7 → gapTolerance = 45s
        for i in 0..<8 {
            sm.tick(
                flowScore: 0.0, // score ignored for transitions
                secondsSinceLastInput: 5, // active
                isMicActive: false,
                isCameraActive: false,
                now: baseTime + Double(i) * 30
            )
        }

        #expect(sm.state == .flow)
    }

    @Test("Gap exceeding tolerance exits flow immediately")
    func flowExitOnGap() {
        let sm = FlowStateMachine()
        let baseTime: TimeInterval = 1000

        // Enter flow
        for i in 0..<8 {
            sm.tick(flowScore: 0.0, secondsSinceLastInput: 5,
                    isMicActive: false, isCameraActive: false,
                    now: baseTime + Double(i) * 30)
        }
        #expect(sm.state == .flow)

        // Gap exceeds tolerance (60s at default 0.7 sensitivity)
        sm.tick(flowScore: 0.0, secondsSinceLastInput: 65,
                isMicActive: false, isCameraActive: false,
                now: baseTime + 270)
        #expect(sm.state == .normal, "Gap > tolerance should exit flow")
    }

    @Test("Gap within tolerance keeps flow")
    func flowMaintainedWithinTolerance() {
        let sm = FlowStateMachine()
        let baseTime: TimeInterval = 1000

        // Enter flow
        for i in 0..<8 {
            sm.tick(flowScore: 0.0, secondsSinceLastInput: 5,
                    isMicActive: false, isCameraActive: false,
                    now: baseTime + Double(i) * 30)
        }
        #expect(sm.state == .flow)

        // Pause within tolerance (30s < 60s at 0.7 sensitivity)
        sm.tick(flowScore: 0.0, secondsSinceLastInput: 30,
                isMicActive: false, isCameraActive: false,
                now: baseTime + 270)
        #expect(sm.state == .flow, "Gap within tolerance should keep flow")
    }

    @Test("Idle detection triggers after 180s of no input")
    func idleDetection() {
        let sm = FlowStateMachine()
        sm.tick(flowScore: 0.0, secondsSinceLastInput: 25,
                isMicActive: false, isCameraActive: false, now: 1000)
        #expect(sm.state == .normal, "25s idle should not trigger idle state")

        sm.tick(flowScore: 0.0, secondsSinceLastInput: 95,
                isMicActive: false, isCameraActive: false, now: 1030)
        #expect(sm.state == .normal, "95s idle should not trigger idle state")

        sm.tick(flowScore: 0.0, secondsSinceLastInput: 185,
                isMicActive: false, isCameraActive: false, now: 1060)
        #expect(sm.state == .idle)
    }

    @Test("Meeting detection when mic is active")
    func meetingDetection() {
        let sm = FlowStateMachine()
        sm.tick(flowScore: 0.0, secondsSinceLastInput: 0,
                isMicActive: true, isCameraActive: false, now: 1000)
        #expect(sm.state == .meeting)
    }

    @Test("Returns to normal after idle, flow must be re-earned")
    func restoreAfterIdle() {
        let sm = FlowStateMachine()
        let baseTime: TimeInterval = 1000

        // Enter flow
        for i in 0..<8 {
            sm.tick(flowScore: 0.0, secondsSinceLastInput: 5,
                    isMicActive: false, isCameraActive: false,
                    now: baseTime + Double(i) * 30)
        }
        #expect(sm.state == .flow)

        // Go idle
        sm.tick(flowScore: 0.0, secondsSinceLastInput: 190,
                isMicActive: false, isCameraActive: false,
                now: baseTime + 300)
        #expect(sm.state == .idle)

        // Resume
        sm.tick(flowScore: 0.0, secondsSinceLastInput: 0,
                isMicActive: false, isCameraActive: false,
                now: baseTime + 330)
        #expect(sm.state == .normal, "After idle, should return to normal — flow must be re-earned")
    }

    @Test("15+ minutes in flow transitions to deep flow")
    func flowToDeepFlow() {
        let sm = FlowStateMachine()
        let baseTime: TimeInterval = 1000

        // 20 minutes of continuous activity (40 ticks at 30s)
        for i in 0..<40 {
            sm.tick(flowScore: 0.0, secondsSinceLastInput: 5,
                    isMicActive: false, isCameraActive: false,
                    now: baseTime + Double(i) * 30)
        }
        #expect(sm.state == .deepFlow)
    }

    @Test("Gap tolerance scales with sensitivity")
    func gapToleranceScaling() {
        let sm = FlowStateMachine()

        sm.flowEntryThreshold = 0.4
        #expect(sm.gapTolerance == 15, "40% sensitivity → 15s tolerance")

        sm.flowEntryThreshold = 0.7
        #expect(Int(sm.gapTolerance.rounded()) == 60, "70% sensitivity → 60s tolerance")

        sm.flowEntryThreshold = 0.9
        #expect(sm.gapTolerance == 90, "90% sensitivity → 90s tolerance")
    }

    @Test("High sensitivity allows longer pauses in flow")
    func highSensitivityLongerPauses() {
        let sm = FlowStateMachine()
        sm.flowEntryThreshold = 0.9 // 90s tolerance
        let baseTime: TimeInterval = 1000

        // Enter flow
        for i in 0..<8 {
            sm.tick(flowScore: 0.0, secondsSinceLastInput: 5,
                    isMicActive: false, isCameraActive: false,
                    now: baseTime + Double(i) * 30)
        }
        #expect(sm.state == .flow)

        // 80s pause — within 90s tolerance
        sm.tick(flowScore: 0.0, secondsSinceLastInput: 80,
                isMicActive: false, isCameraActive: false,
                now: baseTime + 270)
        #expect(sm.state == .flow, "80s pause should keep flow at 90% sensitivity")
    }

    @Test("Low sensitivity breaks flow on short pauses")
    func lowSensitivityShortPauses() {
        let sm = FlowStateMachine()
        sm.flowEntryThreshold = 0.4 // 15s tolerance
        let baseTime: TimeInterval = 1000

        // Enter flow
        for i in 0..<8 {
            sm.tick(flowScore: 0.0, secondsSinceLastInput: 5,
                    isMicActive: false, isCameraActive: false,
                    now: baseTime + Double(i) * 30)
        }
        #expect(sm.state == .flow)

        // 20s pause — exceeds 15s tolerance
        sm.tick(flowScore: 0.0, secondsSinceLastInput: 20,
                isMicActive: false, isCameraActive: false,
                now: baseTime + 270)
        #expect(sm.state == .normal, "20s pause should break flow at 40% sensitivity")
    }
}
