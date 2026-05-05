import Foundation
import Testing
@testable import BlinkCore

@Suite("Integration: Real-world scenarios")
struct IntegrationTests {

    // MARK: - Idle behavior

    @Test("Brief pause (30s) does NOT trigger idle")
    func briefPauseNotIdle() {
        let sm = FlowStateMachine()
        sm.tick(flowScore: 0.5, secondsSinceLastInput: 30,
                isMicActive: false, isCameraActive: false, now: 1000)
        #expect(sm.state == .normal, "30s pause should not be idle — user might be reading or thinking")
    }

    @Test("Walking away (90s+) triggers idle")
    func walkingAwayTriggersIdle() {
        let sm = FlowStateMachine()
        sm.tick(flowScore: 0.5, secondsSinceLastInput: 95,
                isMicActive: false, isCameraActive: false, now: 1000)
        #expect(sm.state == .idle)
    }

    @Test("Idle does NOT flap on brief activity between ticks")
    func idleNoFlapping() {
        let sm = FlowStateMachine()

        // User is working
        sm.tick(flowScore: 0.5, secondsSinceLastInput: 0,
                isMicActive: false, isCameraActive: false, now: 1000)
        #expect(sm.state == .normal)

        // 25s idle — not enough for idle state
        sm.tick(flowScore: 0.5, secondsSinceLastInput: 25,
                isMicActive: false, isCameraActive: false, now: 1030)
        #expect(sm.state == .normal, "25s should not trigger idle")

        // Back to active
        sm.tick(flowScore: 0.5, secondsSinceLastInput: 0,
                isMicActive: false, isCameraActive: false, now: 1060)
        #expect(sm.state == .normal)

        // 35s idle — still not enough
        sm.tick(flowScore: 0.5, secondsSinceLastInput: 35,
                isMicActive: false, isCameraActive: false, now: 1090)
        #expect(sm.state == .normal, "35s should not trigger idle")
    }

    // MARK: - Flow detection with idle interaction

    @Test("Flow is NOT preserved after idle — must be re-earned")
    func flowLostAfterIdle() {
        let sm = FlowStateMachine()
        let base: TimeInterval = 1000

        // Build up flow over 4 minutes
        for i in 0..<8 {
            sm.tick(flowScore: 0.8, secondsSinceLastInput: 0,
                    isMicActive: false, isCameraActive: false,
                    now: base + Double(i) * 30)
        }
        #expect(sm.state == .flow)

        // Go idle for 2 minutes
        sm.tick(flowScore: 0.8, secondsSinceLastInput: 120,
                isMicActive: false, isCameraActive: false,
                now: base + 360)
        #expect(sm.state == .idle)

        // Come back — should be normal, not flow
        sm.tick(flowScore: 0.8, secondsSinceLastInput: 0,
                isMicActive: false, isCameraActive: false,
                now: base + 390)
        #expect(sm.state == .normal, "Flow should not be restored after idle")

        // Need 3+ minutes of high score to re-enter flow
        sm.tick(flowScore: 0.8, secondsSinceLastInput: 0,
                isMicActive: false, isCameraActive: false,
                now: base + 420)
        #expect(sm.state == .normal, "Should still be normal — not enough time to re-enter flow")
    }

    @Test("High flow score during idle does NOT count toward flow entry")
    func idleScoreDoesNotBuildFlow() {
        let sm = FlowStateMachine()
        let base: TimeInterval = 1000

        // Idle with high score (stale buffers) for 4 minutes
        for i in 0..<8 {
            sm.tick(flowScore: 0.9, secondsSinceLastInput: 100 + Double(i) * 30,
                    isMicActive: false, isCameraActive: false,
                    now: base + Double(i) * 30)
        }
        #expect(sm.state == .idle, "Should be idle regardless of high score")

        // Come back
        sm.tick(flowScore: 0.9, secondsSinceLastInput: 0,
                isMicActive: false, isCameraActive: false,
                now: base + 240)
        #expect(sm.state == .normal, "Should be normal — idle time doesn't count toward flow")
    }

    // MARK: - Timer behavior with flow state changes

    @Test("Timer extends proportionally when entering flow")
    func timerExtendsOnFlow() {
        let timer = TimerStateMachine()

        // 10 minutes of normal countdown (50% elapsed)
        timer.tick(flowState: .normal, deltaSeconds: 600)
        #expect(timer.remainingSeconds == 600)

        // Enter flow — should scale to 50% of 30-min flow duration = 15 min remaining
        timer.tick(flowState: .flow, deltaSeconds: 0)
        #expect(timer.remainingSeconds == 900)
    }

    @Test("Timer pauses during idle")
    func timerPausesDuringIdle() {
        let timer = TimerStateMachine()

        // Count down 5 minutes
        timer.tick(flowState: .normal, deltaSeconds: 300)
        let remaining = timer.remainingSeconds
        #expect(remaining == 900)

        // Idle for 2 minutes — timer should not change
        timer.tick(flowState: .idle, deltaSeconds: 120)
        #expect(timer.remainingSeconds == remaining, "Timer must not count down during idle")
    }

    @Test("Timer resets to normal duration after break")
    func timerResetsAfterBreak() {
        let timer = TimerStateMachine()

        // Enter flow, timer extends
        timer.tick(flowState: .normal, deltaSeconds: 300)
        timer.tick(flowState: .flow, deltaSeconds: 0)
        #expect(timer.remainingSeconds > 600, "Should be extended for flow")

        // Reset after break — should go back to normal 20 min
        timer.resetAfterBreak()
        #expect(timer.remainingSeconds == TimerStateMachine.defaultNormalDuration)
    }

    // MARK: - Agent workflow (waiting for AI response)

    @Test("Waiting for agent response with occasional scrolling keeps timer running")
    func agentWorkflowWithScrolling() {
        let sm = FlowStateMachine()
        let base: TimeInterval = 1000

        // User typed a prompt, now scrolling through output
        // idle=5s (just scrolled), then idle=3s, then idle=8s — never hits 90s
        for i in 0..<10 {
            let idle = Double([5, 3, 8, 2, 12, 4, 6, 15, 3, 7][i])
            sm.tick(flowScore: 0.3, secondsSinceLastInput: idle,
                    isMicActive: false, isCameraActive: false,
                    now: base + Double(i) * 30)
        }
        #expect(sm.state == .normal, "Occasional mouse/scroll should prevent idle state")
    }

    @Test("Waiting for agent response sitting perfectly still triggers idle after 90s")
    func agentWorkflowSittingStill() {
        let sm = FlowStateMachine()

        // User sent prompt and is watching output without touching anything
        sm.tick(flowScore: 0.3, secondsSinceLastInput: 95,
                isMicActive: false, isCameraActive: false, now: 1000)
        #expect(sm.state == .idle, "95s of zero input should trigger idle")
    }

    // MARK: - Deep flow

    @Test("Deep flow requires 15+ sustained minutes of flow")
    func deepFlowRequiresSustainedFlow() {
        let sm = FlowStateMachine()
        let base: TimeInterval = 1000

        // 20 minutes of sustained high score (40 ticks at 30s)
        for i in 0..<40 {
            sm.tick(flowScore: 0.85, secondsSinceLastInput: 0,
                    isMicActive: false, isCameraActive: false,
                    now: base + Double(i) * 30)
        }
        #expect(sm.state == .deepFlow)
    }

    @Test("Deep flow lost after idle, cannot skip back to deep flow")
    func deepFlowLostAfterIdle() {
        let sm = FlowStateMachine()
        let base: TimeInterval = 1000

        // Build deep flow
        for i in 0..<40 {
            sm.tick(flowScore: 0.85, secondsSinceLastInput: 0,
                    isMicActive: false, isCameraActive: false,
                    now: base + Double(i) * 30)
        }
        #expect(sm.state == .deepFlow)

        // Go idle
        sm.tick(flowScore: 0.85, secondsSinceLastInput: 100,
                isMicActive: false, isCameraActive: false,
                now: base + 1250)
        #expect(sm.state == .idle)

        // Come back — should be normal, not deep flow
        sm.tick(flowScore: 0.85, secondsSinceLastInput: 0,
                isMicActive: false, isCameraActive: false,
                now: base + 1280)
        #expect(sm.state == .normal)
    }

    // MARK: - Meeting detection

    @Test("Meeting pauses everything, returns to normal after")
    func meetingBehavior() {
        let sm = FlowStateMachine()
        let base: TimeInterval = 1000

        // Build flow
        for i in 0..<8 {
            sm.tick(flowScore: 0.8, secondsSinceLastInput: 0,
                    isMicActive: false, isCameraActive: false,
                    now: base + Double(i) * 30)
        }
        #expect(sm.state == .flow)

        // Meeting starts
        sm.tick(flowScore: 0.8, secondsSinceLastInput: 0,
                isMicActive: true, isCameraActive: false,
                now: base + 300)
        #expect(sm.state == .meeting)

        // Meeting ends — mic off, user is back
        sm.tick(flowScore: 0.5, secondsSinceLastInput: 0,
                isMicActive: false, isCameraActive: false,
                now: base + 600)
        // After meeting, returns to normal (flow must be re-earned)
        #expect(sm.state == .normal)
    }
}
