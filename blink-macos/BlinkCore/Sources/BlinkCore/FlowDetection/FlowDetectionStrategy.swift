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
/// ### V3 — Intentional input with keyboard entry + escalation (proposed)
/// - Flow ENTRY: requires sustained keyboard activity for 3+ minutes
///   (pure clicking/scrolling never enters flow — eliminates casual browsing)
/// - Flow MAINTENANCE: keyboard + clicks + scroll within gap tolerance
///   (excludes mouse moves which are ambient)
/// - Idle detection: any input including mouse moves (to detect walk-away)
/// - Escalation ladder for breaks during flow:
///   - Nudge → wait 20 min → nudge again → eventually force overlay
///   - Nudges before forcing depends on sensitivity:
///     - 40% (strict): force after 1 ignored nudge
///     - 70% (default): force after 3 ignored nudges
///     - 90% (permissive): never force, nudge forever
/// - Pros: keyboard is the strongest flow signal. Browsing correctly stays
///   in normal mode. Designers enter flow via keyboard shortcuts.
///   Sensitivity controls both flow detection AND break aggressiveness.
/// - Cons: not yet built or tested
///
public enum FlowDetectionStrategy: String, CaseIterable, Sendable {
    /// V1: 5-scorer weighted system with hysteresis
    case scoreBased = "v1_score_based"

    /// V2: Activity gap using any input (current default)
    case activityGapAnyInput = "v2_activity_gap"

    /// V3: Keyboard entry, intentional maintenance, escalation ladder
    case intentionalWithEscalation = "v3_intentional_escalation"

    /// Current active strategy
    public static let current: FlowDetectionStrategy = .activityGapAnyInput
}
