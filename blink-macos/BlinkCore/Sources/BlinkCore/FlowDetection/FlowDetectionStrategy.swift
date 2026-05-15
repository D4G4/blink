import Foundation

// MARK: - Strategy Config

/// Which input signals to use for flow detection.
public enum FlowInputMethod: Sendable {
    /// Keyboard, mouse moves, clicks, scroll — everything counts.
    case anyInput
    /// Keyboard + clicks + scroll only. Mouse moves excluded (ambient).
    case intentionalOnly
}

/// How to deliver breaks when the user is in flow.
public enum BreakDeliveryInFlow: Sendable {
    /// Wait for a natural pause (6s idle), then force overlay. If no pause in 5 min, reset silently.
    case waitForPause
    /// Show gentle nudge toast. Timer resets for another 20 min. Never force.
    case nudge
    /// Nudge first, escalate to forced overlay after N ignored nudges.
    case nudgeWithEscalation
}

/// Complete configuration derived from a strategy + sensitivity value.
public struct StrategyConfig: Sendable {
    // Flow detection
    public let flowEntryScoreThreshold: Double
    public let flowExitScoreThreshold: Double
    public let entryGapTolerance: TimeInterval
    public let maintenanceGapTolerance: TimeInterval
    public let flowInputMethod: FlowInputMethod

    // Break delivery
    public let breakDeliveryInFlow: BreakDeliveryInFlow
    public let maxNudgesBeforeForce: Int?

    public var gapTolerance: TimeInterval { entryGapTolerance }
}

// MARK: - Strategy

/// Flow detection strategy versions.
///
/// ## Version History
///
/// ### V1 — Score-based (original)
/// - 5 weighted scorers with hysteresis
/// - Sensitivity controls score threshold
/// - Breaks during flow: wait for natural pause, then forced overlay
/// - Problem: unpredictable, users couldn't understand why flow dropped
///
/// ### V2 — Break Decision Engine (current)
/// - Timer always runs 20 min — NO premature flow extension
/// - Collects signals (keystrokes, clicks, scrolls, app switches) for full 20 min
/// - At break time, evaluates signal density and makes ONE decision:
///   - Skip: < 1 input/min (barely at screen, silent reset)
///   - Nudge: 1-5 inputs/min (low activity, gentle toast)
///   - Show break: 5+ inputs/min, low score (casual use, forced overlay)
///   - Extend: 5+ inputs/min, high score (deep work, extend 10 min + nudge)
/// - Max 2 extensions (20 → 30 → 40 min)
/// - Signals accumulate across extensions for richer evaluation
/// - Uses BreakpointDetector for natural pause detection when delivering breaks
///
public enum FlowDetectionStrategy: String, CaseIterable, Sendable {
    /// V1: 5-scorer weighted system with hysteresis
    case scoreBased = "v1_score_based"

    /// V2: Break Decision Engine — evaluate 20 min of signals at break time
    case breakDecisionEngine = "v2_break_decision"

    /// Current active strategy.
    public static let current: FlowDetectionStrategy = .breakDecisionEngine

    /// Compute the full config for a given sensitivity (0.4–0.9).
    public func config(forSensitivity sensitivity: Double) -> StrategyConfig {
        switch self {
        case .scoreBased:
            return configV1(sensitivity: sensitivity)
        case .breakDecisionEngine:
            return configV2(sensitivity: sensitivity)
        }
    }

    // MARK: - V1 Config

    private func configV1(sensitivity: Double) -> StrategyConfig {
        let entryThreshold = 1.25 - sensitivity
        let exitThreshold = entryThreshold - 0.3

        return StrategyConfig(
            flowEntryScoreThreshold: entryThreshold,
            flowExitScoreThreshold: max(exitThreshold, 0.1),
            entryGapTolerance: 0,
            maintenanceGapTolerance: 0,
            flowInputMethod: .anyInput,
            breakDeliveryInFlow: .waitForPause,
            maxNudgesBeforeForce: nil
        )
    }

    // MARK: - V2 Config (Break Decision Engine)

    /// V2 doesn't use gap tolerance for continuous flow detection.
    /// The sensitivity controls the score threshold in BreakDecisionEngine.decide().
    /// Config here is for the FlowStateMachine which still runs for state display.
    private func configV2(sensitivity: Double) -> StrategyConfig {
        let t = (sensitivity - 0.4) / (0.9 - 0.4)
        let gap = 15.0 + t * 75.0

        return StrategyConfig(
            flowEntryScoreThreshold: 0,
            flowExitScoreThreshold: 0,
            entryGapTolerance: gap,
            maintenanceGapTolerance: gap * 1.5,
            flowInputMethod: .intentionalOnly,
            breakDeliveryInFlow: .nudgeWithEscalation,
            maxNudgesBeforeForce: nil
        )
    }
}
