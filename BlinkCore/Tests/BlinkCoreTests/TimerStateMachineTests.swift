import Testing
@testable import BlinkCore

@Suite("TimerStateMachine")
struct TimerStateMachineTests {
    @Test("Initial state is 20 minutes")
    func initialState() {
        let timer = TimerStateMachine()
        #expect(timer.remainingSeconds == 1200)
        #expect(timer.progress == 0.0)
    }

    @Test("Countdown decreases remaining time")
    func countdown() {
        let timer = TimerStateMachine()
        timer.tick(flowState: .normal, deltaSeconds: 60)
        #expect(timer.remainingSeconds == 1140)
        #expect(timer.progress > 0.0)
    }

    @Test("Fires onBreakDue when time runs out")
    func breakDueFires() {
        let timer = TimerStateMachine()
        var fired = false
        timer.onBreakDue = { fired = true }

        timer.tick(flowState: .normal, deltaSeconds: 1200)
        #expect(fired)
        #expect(timer.remainingSeconds == 0)
    }

    @Test("Pauses during idle")
    func pausesDuringIdle() {
        let timer = TimerStateMachine()
        timer.tick(flowState: .normal, deltaSeconds: 600) // 10 min elapsed
        let remaining = timer.remainingSeconds

        timer.tick(flowState: .idle, deltaSeconds: 120)
        #expect(timer.remainingSeconds == remaining, "Should not decrease during idle")
        #expect(timer.isPaused)
    }

    @Test("Pauses during meeting")
    func pausesDuringMeeting() {
        let timer = TimerStateMachine()
        timer.tick(flowState: .normal, deltaSeconds: 600)
        let remaining = timer.remainingSeconds

        timer.tick(flowState: .meeting, deltaSeconds: 120)
        #expect(timer.remainingSeconds == remaining)
    }

    @Test("Adjusts proportionally when entering flow")
    func adjustsForFlow() {
        let timer = TimerStateMachine()
        // Spend 10 minutes (50%) of 20-minute normal timer
        timer.tick(flowState: .normal, deltaSeconds: 600)
        #expect(timer.remainingSeconds == 600)

        // Enter flow — 30 min timer, should be at 50% = 15 min remaining
        timer.tick(flowState: .flow, deltaSeconds: 0)
        #expect(timer.remainingSeconds == 900, "Should scale to 50% of flow duration (30min), got \(timer.remainingSeconds)")
    }

    @Test("Reset after break restores default")
    func resetAfterBreak() {
        let timer = TimerStateMachine()
        timer.tick(flowState: .normal, deltaSeconds: 1000)
        timer.resetAfterBreak()
        #expect(timer.remainingSeconds == 1200)
        #expect(!timer.isPaused)
    }
}
