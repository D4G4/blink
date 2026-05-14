import Foundation
import Testing
@testable import BlinkCore

@Suite("BreakpointDetector")
struct BreakpointDetectorTests {

    @Test("No breakpoint when no prior keyboard activity")
    func noBreakpointWithoutKeyboard() {
        let detector = BreakpointDetector()

        // Only mouse activity, no keyboard history
        detector.recordInput(
            secondsSinceLastKeystroke: 300,
            secondsSinceLastClick: 2,
            secondsSinceLastScroll: 5,
            now: 1000
        )

        let bp = detector.detectBreakpoint(
            secondsSinceLastKeystroke: 300,
            secondsSinceLastClick: 2,
            secondsSinceLastScroll: 5,
            now: 1000
        )
        #expect(bp == .none, "No breakpoint without prior keyboard activity")
    }

    @Test("Keyboard → mouse transition detected")
    func keyboardToMouseTransition() {
        let detector = BreakpointDetector()

        // Tick 1: user is typing
        detector.recordInput(
            secondsSinceLastKeystroke: 2,
            secondsSinceLastClick: 60,
            secondsSinceLastScroll: 60,
            now: 1000
        )

        // Tick 2: user stopped typing, now clicking
        detector.recordInput(
            secondsSinceLastKeystroke: 15,
            secondsSinceLastClick: 3,
            secondsSinceLastScroll: 50,
            now: 1030
        )

        let bp = detector.detectBreakpoint(
            secondsSinceLastKeystroke: 15,
            secondsSinceLastClick: 3,
            secondsSinceLastScroll: 50,
            now: 1030
        )
        #expect(bp == .keyboardToMouse, "Should detect keyboard → mouse transition")
    }

    @Test("Typing burst then sustained silence")
    func typingBurstThenSilence() {
        let detector = BreakpointDetector()

        // User was typing
        detector.recordInput(
            secondsSinceLastKeystroke: 1,
            secondsSinceLastClick: 120,
            secondsSinceLastScroll: 120,
            now: 1000
        )

        // 35s later: no input at all (> 30s silence threshold)
        let bp = detector.detectBreakpoint(
            secondsSinceLastKeystroke: 35,
            secondsSinceLastClick: 120,
            secondsSinceLastScroll: 120,
            now: 1035
        )
        #expect(bp == .typingBurstThenSilence, "Should detect typing burst → silence")
    }

    @Test("Short pause (15s) is NOT a breakpoint — user is thinking")
    func shortPauseIsThinking() {
        let detector = BreakpointDetector()

        detector.recordInput(
            secondsSinceLastKeystroke: 1,
            secondsSinceLastClick: 120,
            secondsSinceLastScroll: 120,
            now: 1000
        )

        // 15s pause — working memory, mid-thought
        let bp = detector.detectBreakpoint(
            secondsSinceLastKeystroke: 15,
            secondsSinceLastClick: 120,
            secondsSinceLastScroll: 120,
            now: 1015
        )
        #expect(bp == .none, "15s pause should NOT be a breakpoint (user is thinking)")
    }

    @Test("App switch after typing detected")
    func appSwitchAfterTyping() {
        let detector = BreakpointDetector()

        // User was typing
        detector.recordInput(
            secondsSinceLastKeystroke: 2,
            secondsSinceLastClick: 60,
            secondsSinceLastScroll: 60,
            now: 1000
        )

        // App switch happens
        detector.recordAppSwitch(at: 1005)

        let bp = detector.detectBreakpoint(
            secondsSinceLastKeystroke: 7,
            secondsSinceLastClick: 60,
            secondsSinceLastScroll: 60,
            now: 1007
        )
        #expect(bp == .appSwitchAfterTyping, "Should detect app switch after typing")
    }

    @Test("App switch without prior typing is NOT a breakpoint")
    func appSwitchWithoutTyping() {
        let detector = BreakpointDetector()

        // No keyboard activity
        detector.recordInput(
            secondsSinceLastKeystroke: 300,
            secondsSinceLastClick: 5,
            secondsSinceLastScroll: 10,
            now: 1000
        )

        detector.recordAppSwitch(at: 1005)

        let bp = detector.detectBreakpoint(
            secondsSinceLastKeystroke: 300,
            secondsSinceLastClick: 5,
            secondsSinceLastScroll: 10,
            now: 1007
        )
        #expect(bp == .none, "App switch without typing should not be a breakpoint")
    }

    @Test("Reset clears all state")
    func resetClearsState() {
        let detector = BreakpointDetector()

        // Build up keyboard activity
        detector.recordInput(
            secondsSinceLastKeystroke: 1,
            secondsSinceLastClick: 60,
            secondsSinceLastScroll: 60,
            now: 1000
        )

        detector.reset()

        // After reset, sustained silence should NOT trigger breakpoint (no prior keyboard)
        let bp = detector.detectBreakpoint(
            secondsSinceLastKeystroke: 35,
            secondsSinceLastClick: 60,
            secondsSinceLastScroll: 60,
            now: 1035
        )
        #expect(bp == .none, "After reset, no breakpoint should be detected")
    }
}
