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

    @Test("Walking away (180s+) triggers idle")
    func walkingAwayTriggersIdle() {
        let sm = FlowStateMachine()
        sm.tick(flowScore: 0.5, secondsSinceLastInput: 185,
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

    @Test("Idle resets to normal after input resumes")
    func idleResetsToNormal() {
        let sm = FlowStateMachine()
        let base: TimeInterval = 1000

        // Active for a while
        for i in 0..<8 {
            sm.tick(flowScore: 0.8, secondsSinceLastInput: 0,
                    isMicActive: false, isCameraActive: false,
                    now: base + Double(i) * 30)
        }
        #expect(sm.state == .normal)

        // Go idle for 3+ minutes
        sm.tick(flowScore: 0.8, secondsSinceLastInput: 190,
                isMicActive: false, isCameraActive: false,
                now: base + 360)
        #expect(sm.state == .idle)

        // Come back — should be normal
        sm.tick(flowScore: 0.8, secondsSinceLastInput: 0,
                isMicActive: false, isCameraActive: false,
                now: base + 390)
        #expect(sm.state == .normal)
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

    @Test("Waiting for agent response sitting perfectly still triggers idle after 180s")
    func agentWorkflowSittingStill() {
        let sm = FlowStateMachine()

        // User sent prompt and is watching output without touching anything
        sm.tick(flowScore: 0.3, secondsSinceLastInput: 185,
                isMicActive: false, isCameraActive: false, now: 1000)
        #expect(sm.state == .idle, "185s of zero input should trigger idle")
    }

    @Test("Continuous activity stays normal — flow detection is deferred to BreakDecisionEngine")
    func continuousActivityStaysNormal() {
        let sm = FlowStateMachine()
        let base: TimeInterval = 1000

        // 20 minutes of continuous activity — should NOT enter flow
        for i in 0..<40 {
            sm.tick(flowScore: 0.85, secondsSinceLastInput: 0,
                    secondsSinceLastIntentionalInput: 3,
                    isMicActive: false, isCameraActive: false,
                    now: base + Double(i) * 30)
        }
        #expect(sm.state == .normal, "FlowStateMachine no longer detects flow — only idle/meeting")
    }

    // MARK: - Meeting detection

    @Test("Meeting pauses everything, returns to normal after")
    func meetingBehavior() {
        let sm = FlowStateMachine()
        let base: TimeInterval = 1000

        // Active for a while
        for i in 0..<8 {
            sm.tick(flowScore: 0.8, secondsSinceLastInput: 0,
                    isMicActive: false, isCameraActive: false,
                    now: base + Double(i) * 30)
        }
        #expect(sm.state == .normal)

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
