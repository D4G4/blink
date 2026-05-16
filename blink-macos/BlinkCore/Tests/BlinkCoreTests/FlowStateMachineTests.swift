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

    // Helper: tick with both score and intentional input
    private func activeTick(
        _ sm: FlowStateMachine,
        score: Double = 0.5,
        intentionalIdle: TimeInterval = 3,
        now: TimeInterval
    ) {
        sm.tick(
            flowScore: score,
            secondsSinceLastInput: 0,
            secondsSinceLastIntentionalInput: intentionalIdle,
            isMicActive: false,
            isCameraActive: false,
            now: now
        )
    }

    private func enterFlow(_ sm: FlowStateMachine, baseTime: TimeInterval = 1000) {
        // 8 ticks × 30s = 240s > 180s entry duration, score 0.5 > 0.35 threshold
        for i in 0..<8 {
            activeTick(sm, score: 0.5, intentionalIdle: 3, now: baseTime + Double(i) * 30)
        }
    }

    @Test("Continuous activity with sufficient score enters flow")
    func normalToFlow() {
        let sm = FlowStateMachine()
        let baseTime: TimeInterval = 1000
        enterFlow(sm, baseTime: baseTime)
        #expect(sm.state == .flow)
    }

    @Test("Low flow score prevents flow entry even with continuous input")
    func lowScoreBlocksFlow() {
        let sm = FlowStateMachine()
        let baseTime: TimeInterval = 1000

        // 8 ticks with low score (0.2 < 0.35 threshold)
        for i in 0..<8 {
            activeTick(sm, score: 0.2, intentionalIdle: 3, now: baseTime + Double(i) * 30)
        }
        #expect(sm.state == .normal, "Score 0.2 is below 0.35 threshold — should not enter flow")
    }

    @Test("Gap exceeding maintenance tolerance exits flow")
    func flowExitOnGap() {
        let sm = FlowStateMachine()
        let baseTime: TimeInterval = 1000
        enterFlow(sm, baseTime: baseTime)
        #expect(sm.state == .flow)

        // Default sensitivity 0.7: entry=18.5s, maintenance=27.75s
        // 30s pause exceeds maintenance tolerance
        activeTick(sm, score: 0.5, intentionalIdle: 30, now: baseTime + 270)
        #expect(sm.state == .normal, "Gap > maintenance tolerance should exit flow")
    }

    @Test("Gap within maintenance tolerance keeps flow")
    func flowMaintainedWithinTolerance() {
        let sm = FlowStateMachine()
        let baseTime: TimeInterval = 1000
        enterFlow(sm, baseTime: baseTime)
        #expect(sm.state == .flow)

        // Default sensitivity 0.7: maintenance = 18.5 * 1.5 = 27.75s
        // 20s pause is within tolerance
        activeTick(sm, score: 0.5, intentionalIdle: 20, now: baseTime + 270)
        #expect(sm.state == .flow, "Gap within maintenance tolerance should keep flow")
    }

    @Test("Idle detection triggers after 180s of no input")
    func idleDetection() {
        let sm = FlowStateMachine()
        activeTick(sm, intentionalIdle: 25, now: 1000)
        #expect(sm.state == .normal, "25s idle should not trigger idle state")

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
        enterFlow(sm, baseTime: baseTime)
        #expect(sm.state == .flow)

        // Go idle
        sm.tick(flowScore: 0.0, secondsSinceLastInput: 190,
                isMicActive: false, isCameraActive: false, now: baseTime + 300)
        #expect(sm.state == .idle)

        // Resume
        activeTick(sm, now: baseTime + 330)
        #expect(sm.state == .normal, "After idle, should return to normal — flow must be re-earned")
    }

    @Test("15+ minutes in flow transitions to deep flow")
    func flowToDeepFlow() {
        let sm = FlowStateMachine()
        let baseTime: TimeInterval = 1000

        // 40 ticks × 30s = 1200s = 20 min (flow entry at 3 min, deep at 15 min after)
        for i in 0..<40 {
            activeTick(sm, score: 0.5, intentionalIdle: 3, now: baseTime + Double(i) * 30)
        }
        #expect(sm.state == .deepFlow)
    }

    @Test("Gap tolerance scales with sensitivity")
    func gapToleranceScaling() {
        let sm = FlowStateMachine()

        sm.sensitivity = 0.4
        #expect(sm.config.entryGapTolerance == 8, "40% sensitivity → 8s tolerance")

        sm.sensitivity = 0.7
        // t = 0.6, gap = 8 + 0.6 * 17 = 18.2
        #expect(Int(sm.config.entryGapTolerance.rounded()) == 18, "70% sensitivity → ~18s tolerance")

        sm.sensitivity = 0.9
        #expect(sm.config.entryGapTolerance == 25, "90% sensitivity → 25s tolerance")
    }

    @Test("High sensitivity allows longer pauses in flow")
    func highSensitivityLongerPauses() {
        let sm = FlowStateMachine()
        sm.sensitivity = 0.9 // entry=25s, maintenance=37.5s
        let baseTime: TimeInterval = 1000
        enterFlow(sm, baseTime: baseTime)
        #expect(sm.state == .flow)

        // 30s pause — within 37.5s maintenance tolerance
        activeTick(sm, intentionalIdle: 30, now: baseTime + 270)
        #expect(sm.state == .flow, "30s pause should keep flow at 90% sensitivity (maintenance=37.5s)")
    }

    @Test("Low sensitivity breaks flow on short pauses")
    func lowSensitivityShortPauses() {
        let sm = FlowStateMachine()
        sm.sensitivity = 0.4 // entry=8s, maintenance=12s
        let baseTime: TimeInterval = 1000
        enterFlow(sm, baseTime: baseTime)
        #expect(sm.state == .flow)

        // 15s pause — exceeds 12s maintenance tolerance
        activeTick(sm, intentionalIdle: 15, now: baseTime + 270)
        #expect(sm.state == .normal, "15s pause should break flow at 40% sensitivity (maintenance=12s)")
    }

    @Test("Maintenance tolerance is more forgiving than entry")
    func maintenanceMoreForgiving() {
        let sm = FlowStateMachine()
        sm.sensitivity = 0.7 // entry=18.2s, maintenance=27.3s
        let baseTime: TimeInterval = 1000
        enterFlow(sm, baseTime: baseTime)
        #expect(sm.state == .flow)

        // 22s pause — exceeds entry (18.2s) but within maintenance (27.3s)
        activeTick(sm, intentionalIdle: 22, now: baseTime + 270)
        #expect(sm.state == .flow, "22s pause should keep flow (within maintenance tolerance)")
    }

    @Test("Mouse-only browsing never enters flow")
    func mouseOnlyNoFlow() {
        let sm = FlowStateMachine()
        let baseTime: TimeInterval = 1000

        // 10 ticks — mouse moves only, intentional input growing stale
        for i in 0..<10 {
            sm.tick(flowScore: 0.0, secondsSinceLastInput: 0,
                    secondsSinceLastIntentionalInput: Double(i) * 30 + 30,
                    isMicActive: false, isCameraActive: false,
                    now: baseTime + Double(i) * 30)
        }
        #expect(sm.state == .normal, "Mouse-only browsing should never enter flow")
    }

    @Test("Score just at threshold allows flow entry")
    func scoreAtThreshold() {
        let sm = FlowStateMachine()
        let baseTime: TimeInterval = 1000

        // Score exactly 0.35 (the threshold)
        for i in 0..<8 {
            activeTick(sm, score: 0.35, intentionalIdle: 3, now: baseTime + Double(i) * 30)
        }
        #expect(sm.state == .flow, "Score at threshold (0.35) should allow flow entry")
    }
}
