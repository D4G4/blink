import Foundation

/// Manages flow state transitions based on activity gaps.
///
/// Instead of a weighted multi-scorer approach, flow is determined by
/// a single metric: how long since the last input? If the user has been
/// continuously active (no gap exceeding the tolerance) for 3+ minutes,
/// they're in flow. One pause that exceeds the tolerance breaks flow.
///
/// The sensitivity slider controls gap tolerance:
///   40% → 15s (strict)  ...  70% → 45s (default)  ...  90% → 90s (forgiving)
public final class FlowStateMachine {
    public private(set) var state: FlowState = .normal
    public var onStateChange: ((_ old: FlowState, _ new: FlowState) -> Void)?

    // Activity tracking
    private var continuousActivityStart: TimeInterval?
    private var flowEntrySince: TimeInterval?

    // Threshold defaults
    public static let defaultFlowEntryThreshold: Double = 0.7  // sensitivity (maps to gap tolerance)
    public static let defaultFlowExitThreshold: Double = 0.4   // unused, kept for API compat
    public static let defaultFlowEntryDuration: TimeInterval = 180    // 3 minutes of activity
    public static let defaultFlowExitDuration: TimeInterval = 120     // unused, kept for API compat
    public static let defaultDeepFlowDuration: TimeInterval = 900     // 15 minutes in flow
    public static let defaultIdleThreshold: TimeInterval = 180        // 3 min idle = away

    // Configurable thresholds
    public var flowEntryThreshold: Double = defaultFlowEntryThreshold  // sensitivity
    public var flowExitThreshold: Double = defaultFlowExitThreshold
    public var flowEntryDuration: TimeInterval = defaultFlowEntryDuration
    public var flowExitDuration: TimeInterval = defaultFlowExitDuration
    public var deepFlowDuration: TimeInterval = defaultDeepFlowDuration
    public var idleThreshold: TimeInterval = defaultIdleThreshold

    // Previous state before idle/meeting (to restore)
    private var stateBeforePause: FlowState?

    public init() {}

    /// Gap tolerance in seconds, derived from the sensitivity slider (0.4–0.9).
    /// Higher sensitivity = longer tolerance = easier to stay in flow.
    public var gapTolerance: TimeInterval {
        // 0.4 → 15s, 0.9 → 90s (linear)
        let t = (flowEntryThreshold - 0.4) / (0.9 - 0.4)
        return 15 + t * 75
    }

    /// Called every 30 seconds by the app's tick loop.
    /// flowScore is kept for display but NOT used for state transitions.
    public func tick(
        flowScore: Double,
        secondsSinceLastInput: TimeInterval,
        isMicActive: Bool,
        isCameraActive: Bool,
        now: TimeInterval
    ) {
        // Meeting detection takes priority
        if isMicActive || isCameraActive {
            if state != .meeting {
                stateBeforePause = state
                transition(to: .meeting)
            }
            return
        }

        // Idle detection (walked away)
        if secondsSinceLastInput >= idleThreshold {
            if state != .idle {
                stateBeforePause = state
                transition(to: .idle)
            }
            return
        }

        // Returning from idle/meeting
        if state == .idle || state == .meeting {
            stateBeforePause = nil
            continuousActivityStart = nil
            flowEntrySince = nil
            transition(to: .normal)
        }

        // Skip flow calculations during break
        if state == .breakPrompted { return }

        // Activity-gap based flow detection
        let isActive = secondsSinceLastInput < gapTolerance

        if isActive {
            if continuousActivityStart == nil {
                continuousActivityStart = now
            }
        } else {
            // Gap exceeded tolerance — break continuous activity
            continuousActivityStart = nil
        }

        switch state {
        case .normal:
            // Enter flow after sustained activity
            if let start = continuousActivityStart,
               now - start >= flowEntryDuration {
                flowEntrySince = now
                transition(to: .flow)
            }

        case .flow:
            if !isActive {
                // Gap exceeded tolerance — exit flow
                flowEntrySince = nil
                continuousActivityStart = nil
                transition(to: .normal)
            } else if let flowStart = flowEntrySince,
                      now - flowStart >= deepFlowDuration {
                transition(to: .deepFlow)
            }

        case .deepFlow:
            if !isActive {
                flowEntrySince = nil
                continuousActivityStart = nil
                transition(to: .normal)
            }

        case .idle, .meeting, .breakPrompted:
            break
        }
    }

    /// Enter break-prompted state. Call when the timer fires.
    public func enterBreakPrompted() {
        transition(to: .breakPrompted)
    }

    /// Exit break-prompted state after break is taken or dismissed.
    public func exitBreakPrompted() {
        flowEntrySince = nil
        continuousActivityStart = nil
        transition(to: .normal)
    }

    // MARK: - Private

    private func transition(to newState: FlowState) {
        guard newState != state else { return }
        let old = state
        state = newState
        onStateChange?(old, newState)
    }
}
