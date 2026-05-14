import Foundation

/// Detects natural task boundaries ("breakpoints") where interruptions are least disruptive.
///
/// Based on research showing that interruptions at task boundaries cost 32% less
/// than mid-task interruptions (Frontiers in Psychology, 2024). And that 2-15 second
/// pauses during programming indicate active working memory — the worst time to interrupt
/// (Shrestha, IEEE ICSE-SEET, 2022).
///
/// Instead of a simple idle timer, this detects compound signals that indicate
/// a user has finished a thought and is transitioning between tasks:
///
/// 1. **Keyboard → mouse transition**: stopped typing, started clicking/scrolling
/// 2. **Typing burst → sustained silence (30s+)**: completed a unit of work
/// 3. **App switch after typing**: moved to different context
///
/// Usage:
///   Call `recordInput()` on every input event from the idle detector tick.
///   Call `isAtBreakpoint()` to check if the user is currently at a natural boundary.
public final class BreakpointDetector {

    /// The type of input most recently observed.
    public enum InputMode: Equatable, Sendable {
        case keyboard
        case mouse    // clicks + scroll (not moves)
        case none
    }

    /// A detected breakpoint and what triggered it.
    public enum BreakpointType: Equatable, Sendable {
        /// User switched from typing to mouse interaction
        case keyboardToMouse
        /// Burst of typing followed by 30s+ of silence
        case typingBurstThenSilence
        /// User switched apps after a typing session
        case appSwitchAfterTyping
        /// No breakpoint detected
        case none
    }

    // State
    private var currentMode: InputMode = .none
    private var previousMode: InputMode = .none
    private var lastKeyboardInputAt: TimeInterval = 0
    private var lastMouseInputAt: TimeInterval = 0
    private var lastAppSwitchAt: TimeInterval = 0
    private var hadKeyboardActivityRecently: Bool = false

    /// How long after last keyboard input before a silence counts as "sustained"
    public var silenceThreshold: TimeInterval = 30

    /// How recently keyboard must have been used for a transition to count
    public var recentKeyboardWindow: TimeInterval = 120  // 2 minutes

    public init() {}

    // MARK: - Record Input

    /// Call on each tick (every 30s) with the current idle times.
    /// Updates internal state tracking input mode transitions.
    public func recordInput(
        secondsSinceLastKeystroke: TimeInterval,
        secondsSinceLastClick: TimeInterval,
        secondsSinceLastScroll: TimeInterval,
        now: TimeInterval
    ) {
        // Determine current dominant input mode
        let keyboardActive = secondsSinceLastKeystroke < 5
        let mouseActive = min(secondsSinceLastClick, secondsSinceLastScroll) < 5

        previousMode = currentMode

        if keyboardActive {
            currentMode = .keyboard
            lastKeyboardInputAt = now
            hadKeyboardActivityRecently = true
        } else if mouseActive {
            currentMode = .mouse
            lastMouseInputAt = now
        } else {
            currentMode = .none
        }

        // Decay "recent keyboard" flag after window expires
        if now - lastKeyboardInputAt > recentKeyboardWindow {
            hadKeyboardActivityRecently = false
        }
    }

    /// Call when an app switch is detected.
    public func recordAppSwitch(at now: TimeInterval) {
        lastAppSwitchAt = now
    }

    // MARK: - Detect Breakpoint

    /// Check if the user is currently at a natural task boundary.
    /// Call this when a break is pending and you're waiting for the right moment.
    public func detectBreakpoint(
        secondsSinceLastKeystroke: TimeInterval,
        secondsSinceLastClick: TimeInterval,
        secondsSinceLastScroll: TimeInterval,
        now: TimeInterval
    ) -> BreakpointType {

        let mouseActive = min(secondsSinceLastClick, secondsSinceLastScroll) < 10

        // 1. Keyboard → mouse transition
        //    User was typing recently, now using mouse = finished typing, navigating
        if hadKeyboardActivityRecently && mouseActive && secondsSinceLastKeystroke > 10 {
            return .keyboardToMouse
        }

        // 2. Typing burst → sustained silence
        //    Had keyboard activity, now silence for 30s+ = completed a thought
        //    (NOT 2-15s which is working memory / mid-thought)
        if hadKeyboardActivityRecently && secondsSinceLastKeystroke >= silenceThreshold {
            return .typingBurstThenSilence
        }

        // 3. App switch after typing
        //    Switched apps within the last 10s AND had keyboard activity = context change
        if hadKeyboardActivityRecently && (now - lastAppSwitchAt) < 10 {
            return .appSwitchAfterTyping
        }

        return .none
    }

    /// Simple convenience: is there ANY breakpoint right now?
    public func isAtBreakpoint(
        secondsSinceLastKeystroke: TimeInterval,
        secondsSinceLastClick: TimeInterval,
        secondsSinceLastScroll: TimeInterval,
        now: TimeInterval
    ) -> Bool {
        detectBreakpoint(
            secondsSinceLastKeystroke: secondsSinceLastKeystroke,
            secondsSinceLastClick: secondsSinceLastClick,
            secondsSinceLastScroll: secondsSinceLastScroll,
            now: now
        ) != .none
    }

    /// Reset all state (after break taken or flow exits).
    public func reset() {
        currentMode = .none
        previousMode = .none
        lastKeyboardInputAt = 0
        lastMouseInputAt = 0
        lastAppSwitchAt = 0
        hadKeyboardActivityRecently = false
    }
}
