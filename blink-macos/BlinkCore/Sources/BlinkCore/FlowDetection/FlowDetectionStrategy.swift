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
/// One source of truth — FlowStateMachine and AppState both read from this.
public struct StrategyConfig: Sendable {
    // Flow detection
    public let flowEntryScoreThreshold: Double    // V1: score needed for flow
    public let flowExitScoreThreshold: Double     // V1: score to exit flow
    public let entryGapTolerance: TimeInterval    // V3: stricter tolerance for entering flow
    public let maintenanceGapTolerance: TimeInterval // V3: more forgiving for staying in flow
    public let flowInputMethod: FlowInputMethod

    // Break delivery
    public let breakDeliveryInFlow: BreakDeliveryInFlow
    /// How many nudges before escalating to forced overlay. nil = never force.
    public let maxNudgesBeforeForce: Int?

    /// Convenience: single gap tolerance for V2 (entry == maintenance)
    public var gapTolerance: TimeInterval { entryGapTolerance }
}

// MARK: - Strategy

/// Flow detection strategy versions.
/// See version history docs below. Switch via `FlowDetectionStrategy.current`.
///
/// ## Version History
///
/// ### V1 — Score-based (original)
/// - 5 weighted scorers with hysteresis
/// - Sensitivity controls score threshold (high sensitivity → lower threshold → easier flow)
/// - Breaks during flow: wait for natural pause, then forced overlay
///
/// ### V2 — Activity gap, any input (current)
/// - Single gap metric using all input (including mouse moves)
/// - Sensitivity controls gap tolerance (high sensitivity → longer tolerance → easier flow)
/// - Breaks during flow: gentle nudge, never forced
///
/// ### V3 — Intentional input + escalation (proposed)
/// - Keyboard + clicks + scroll for flow (mouse moves excluded)
/// - Sensitivity controls gap tolerance AND escalation aggressiveness
/// - Breaks during flow: nudge → escalate to forced overlay after N ignored nudges
///
public enum FlowDetectionStrategy: String, CaseIterable, Sendable {
    case scoreBased = "v1_score_based"
    case activityGapAnyInput = "v2_activity_gap"
    case intentionalWithEscalation = "v3_intentional_escalation"

    /// Current active strategy. Change this one line to switch.
    public static let current: FlowDetectionStrategy = .activityGapAnyInput

    /// Compute the full config for a given sensitivity (0.4–0.9).
    public func config(forSensitivity sensitivity: Double) -> StrategyConfig {
        switch self {
        case .scoreBased:
            return configV1(sensitivity: sensitivity)
        case .activityGapAnyInput:
            return configV2(sensitivity: sensitivity)
        case .intentionalWithEscalation:
            return configV3(sensitivity: sensitivity)
        }
    }

    // MARK: - V1 Config

    /// V1: sensitivity inversely maps to score threshold.
    /// High sensitivity (0.9) → low threshold (0.45) → easy to enter flow.
    /// Low sensitivity (0.4) → high threshold (0.85) → hard to enter flow.
    private func configV1(sensitivity: Double) -> StrategyConfig {
        // Linear inverse: 0.4 → 0.85, 0.9 → 0.45
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

    // MARK: - V2 Config

    /// V2: sensitivity maps to gap tolerance.
    /// High sensitivity (0.9) → 90s tolerance → easy to stay in flow.
    /// Low sensitivity (0.4) → 15s tolerance → hard to stay in flow.
    private func configV2(sensitivity: Double) -> StrategyConfig {
        let t = (sensitivity - 0.4) / (0.9 - 0.4)
        let gap = 15.0 + t * 75.0

        return StrategyConfig(
            flowEntryScoreThreshold: 0,
            flowExitScoreThreshold: 0,
            entryGapTolerance: gap,
            maintenanceGapTolerance: gap, // same for V2
            flowInputMethod: .anyInput,
            breakDeliveryInFlow: .nudge,
            maxNudgesBeforeForce: nil
        )
    }

    // MARK: - V3 Config

    /// V3: sensitivity maps to gap tolerance AND escalation aggressiveness.
    /// High sensitivity (0.9) → 90s tolerance, never force overlay.
    /// Low sensitivity (0.4) → 15s tolerance, force after 1 ignored nudge.
    /// V3: two-tier tolerance + escalation.
    /// Entry is stricter (keyboard-focused), maintenance is 1.5x more forgiving.
    /// This handles agent workflows: type a prompt, wait 90s for response while
    /// scrolling — maintenance tolerance keeps flow alive during the wait.
    private func configV3(sensitivity: Double) -> StrategyConfig {
        let t = (sensitivity - 0.4) / (0.9 - 0.4)
        let entryGap = 15.0 + t * 75.0              // same base as V2
        let maintenanceGap = entryGap * 1.5          // 1.5x more forgiving

        // Escalation: low sensitivity = aggressive, high = patient
        let maxNudges: Int?
        switch sensitivity {
        case ..<0.55:  maxNudges = 1
        case ..<0.65:  maxNudges = 2
        case ..<0.75:  maxNudges = 3
        case ..<0.85:  maxNudges = 5
        default:       maxNudges = nil // never force
        }

        return StrategyConfig(
            flowEntryScoreThreshold: 0,
            flowExitScoreThreshold: 0,
            entryGapTolerance: entryGap,
            maintenanceGapTolerance: maintenanceGap,
            flowInputMethod: .intentionalOnly,
            breakDeliveryInFlow: .nudgeWithEscalation,
            maxNudgesBeforeForce: maxNudges
        )
    }
}
