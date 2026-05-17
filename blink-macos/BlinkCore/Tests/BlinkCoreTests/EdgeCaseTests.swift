import Foundation
import Testing
@testable import BlinkCore

@Suite("Edge cases and safety")
struct EdgeCaseTests {

    // MARK: - Timer edge cases

    @Test("Timer does not go negative")
    func timerNeverNegative() {
        let timer = TimerStateMachine()
        timer.tick(flowState: .normal, deltaSeconds: 9999)
        #expect(timer.remainingSeconds == 0)
        #expect(timer.progress == 1.0)
    }

    @Test("Timer progress is always 0-1")
    func progressClamped() {
        let timer = TimerStateMachine()
        #expect(timer.progress >= 0 && timer.progress <= 1)

        timer.tick(flowState: .normal, deltaSeconds: 600)
        #expect(timer.progress >= 0 && timer.progress <= 1)

        timer.tick(flowState: .normal, deltaSeconds: 9999)
        #expect(timer.progress >= 0 && timer.progress <= 1)
    }

    @Test("Timer handles zero delta")
    func zeroDelta() {
        let timer = TimerStateMachine()
        let before = timer.remainingSeconds
        timer.tick(flowState: .normal, deltaSeconds: 0)
        #expect(timer.remainingSeconds == before)
    }

    @Test("Timer reset after break resets to default duration")
    func resetAfterBreak() {
        let timer = TimerStateMachine()
        timer.tick(flowState: .normal, deltaSeconds: 100)
        timer.resetAfterBreak()
        #expect(timer.remainingSeconds == TimerStateMachine.defaultDuration)
    }

    @Test("onBreakDue fires exactly once")
    func breakDueFiresOnce() {
        let timer = TimerStateMachine()
        var fireCount = 0
        timer.onBreakDue = { fireCount += 1 }

        timer.tick(flowState: .normal, deltaSeconds: 1200)
        #expect(fireCount == 1)

        // Ticking again at 0 should not re-fire
        timer.tick(flowState: .normal, deltaSeconds: 1)
        #expect(fireCount == 1, "Should not fire again after reaching 0")
    }

    // MARK: - Flow state machine edge cases

    @Test("Flow state machine handles rapid ticks")
    func rapidTicks() {
        let sm = FlowStateMachine()
        // 100 rapid ticks with varying scores — should not crash
        for i in 0..<100 {
            let score = Double(i % 10) / 10.0
            sm.tick(flowScore: score, secondsSinceLastInput: 0,
                    isMicActive: false, isCameraActive: false,
                    now: Double(i))
        }
        // Just verify it didn't crash and has a valid state
        #expect([FlowState.normal, .flow, .deepFlow, .idle, .meeting, .breakPrompted].contains(sm.state))
    }

    @Test("Flow state machine handles simultaneous mic and idle")
    func micAndIdle() {
        let sm = FlowStateMachine()
        // Meeting takes priority over idle
        sm.tick(flowScore: 0.5, secondsSinceLastInput: 200,
                isMicActive: true, isCameraActive: false, now: 1000)
        #expect(sm.state == .meeting, "Meeting should take priority over idle")
    }

    @Test("Flow state machine enterBreakPrompted and exit")
    func breakPromptedCycle() {
        let sm = FlowStateMachine()
        sm.enterBreakPrompted()
        #expect(sm.state == .breakPrompted)

        sm.exitBreakPrompted()
        #expect(sm.state == .normal)
    }

    @Test("Flow state machine exitBreakPrompted returns to normal")
    func exitBreakResetsToNormal() {
        let sm = FlowStateMachine()
        let base: TimeInterval = 1000

        // Active for a while
        for i in 0..<8 {
            sm.tick(flowScore: 0.8, secondsSinceLastInput: 0,
                    isMicActive: false, isCameraActive: false,
                    now: base + Double(i) * 30)
        }
        #expect(sm.state == .normal, "No flow detection — stays normal")

        // Break
        sm.enterBreakPrompted()
        sm.exitBreakPrompted()
        #expect(sm.state == .normal)

        // More activity — still normal (no flow detection)
        sm.tick(flowScore: 0.9, secondsSinceLastInput: 0,
                isMicActive: false, isCameraActive: false,
                now: base + 300)
        #expect(sm.state == .normal, "Flow should require 3+ min to re-enter after break")
    }

    // MARK: - Compliance tracker edge cases

    @Test("Double prompt overwrites previous")
    func doublePrompt() {
        let tracker = BreakComplianceTracker()
        var recorded: BreakRecord?
        tracker.onBreakRecorded = { recorded = $0 }

        tracker.breakPrompted(at: Date(), flowState: .normal, flowScore: 0.3)
        tracker.breakPrompted(at: Date(), flowState: .flow, flowScore: 0.9)
        tracker.breakTaken(at: Date(), idleDuration: 20)

        #expect(recorded?.flowStateWhenPrompted == .flow, "Second prompt should overwrite first")
        #expect(recorded?.flowScore == 0.9)
    }

}
