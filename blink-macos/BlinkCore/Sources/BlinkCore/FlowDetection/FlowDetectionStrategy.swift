import Foundation

/// Flow detection strategy versions.
/// Switch between these to test different approaches or revert regressions.
///
/// ## Version History
///
/// ### V1 — Score-based (original)
/// - 5 weighted scorers: app switches (35%), keystrokes (25%), mouse (20%),
///   window stability (10%), context bonus (10%)
/// - Flow entry: composite score > 0.7 sustained for 3 minutes
/// - Flow exit: score < 0.4 sustained for 2 minutes (hysteresis prevents flapping)
/// - Break during flow: waits for natural pause (6s idle), then forced overlay
/// - If no pause within 5 min, timer resets silently
/// - Pros: considers multiple signals, hysteresis prevents flapping
/// - Cons: unpredictable — users couldn't understand why flow dropped.
///   Score oscillated around thresholds during normal work patterns.
///   App switches for reference material killed the score.
///
/// ### V2 — Activity gap, any input (current)
/// - Single metric: time since last input (keyboard, mouse moves, clicks, scroll)
/// - Gap tolerance controlled by sensitivity slider (40%=15s ... 90%=90s)
/// - Flow entry: continuous activity (no gap > tolerance) for 3+ minutes
/// - Flow exit: any single gap > tolerance
/// - Break during flow: gentle nudge toast (7s auto-dismiss), not forced overlay
/// - Timer resets for another 20 min after nudge
/// - Pros: simple, predictable, one metric, sensitivity slider is intuitive
/// - Cons: too permissive — mouse moves happen constantly, so everyone is
///   "active" 100% of the time. Flow triggers for casual browsing.
///   Users report it never interrupts them.
///
/// ### V3 — Activity gap, intentional input only (proposed)
/// - Same gap model as V2, but excludes mouse MOVES from flow detection
/// - Flow uses: keyboard + clicks + scroll (intentional actions)
/// - Idle uses: any input including mouse moves (to detect walk-away)
/// - Pros: fixes V2's permissiveness — casual mouse browsing won't trigger flow
/// - Cons: not yet tested with real users
///
/// ### V4 — Keyboard entry, intentional maintenance (proposed)
/// - Flow ENTRY requires sustained keyboard activity for 3+ minutes
/// - Flow MAINTENANCE allows keyboard + clicks + scroll within gap tolerance
/// - Pure clicking/scrolling (no keyboard) never enters flow
/// - Escalation: nudge → nudge → forced overlay (count depends on sensitivity)
///   - 40% sensitivity: force after 1 ignored nudge
///   - 70% sensitivity: force after 3 ignored nudges
///   - 90% sensitivity: never force, nudge forever
/// - Pros: keyboard is the strongest flow signal. Browsing (no keyboard) correctly
///   stays in normal mode. Designers still enter flow via keyboard shortcuts.
/// - Cons: more complex, not yet built
///
public enum FlowDetectionStrategy: String, CaseIterable, Sendable {
    /// V1: 5-scorer weighted system with hysteresis
    case scoreBased = "v1_score_based"

    /// V2: Activity gap using any input (current default)
    case activityGapAnyInput = "v2_activity_gap"

    /// V3: Activity gap using intentional input only (keyboard + clicks + scroll)
    case activityGapIntentional = "v3_intentional_input"

    /// V4: Keyboard required for entry, intentional input for maintenance
    case keyboardEntry = "v4_keyboard_entry"

    /// Current active strategy
    public static let current: FlowDetectionStrategy = .activityGapAnyInput
}
