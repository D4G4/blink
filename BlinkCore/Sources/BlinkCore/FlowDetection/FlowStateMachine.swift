import Foundation

/// Manages flow state transitions with hysteresis to prevent flapping.
public final class FlowStateMachine {
    public private(set) var state: FlowState = .normal
    public var onStateChange: ((_ old: FlowState, _ new: FlowState) -> Void)?

    // Hysteresis tracking
    private var scoreAboveFlowThresholdSince: TimeInterval?
    private var scoreBelowExitThresholdSince: TimeInterval?
    private var flowEntrySince: TimeInterval? // when we first entered flow

    // Threshold defaults
    public static let defaultFlowEntryThreshold: Double = 0.7
    public static let defaultFlowExitThreshold: Double = 0.4
    public static let defaultFlowEntryDuration: TimeInterval = 180    // 3 minutes
    public static let defaultFlowExitDuration: TimeInterval = 120     // 2 minutes
    public static let defaultDeepFlowDuration: TimeInterval = 900     // 15 minutes in flow
    public static let defaultIdleThreshold: TimeInterval = 90         // match AppState idle break threshold

    // Configurable thresholds
    public var flowEntryThreshold: Double = defaultFlowEntryThreshold
    public var flowExitThreshold: Double = defaultFlowExitThreshold
    public var flowEntryDuration: TimeInterval = defaultFlowEntryDuration
    public var flowExitDuration: TimeInterval = defaultFlowExitDuration
    public var deepFlowDuration: TimeInterval = defaultDeepFlowDuration
    public var idleThreshold: TimeInterval = defaultIdleThreshold

    // Previous state before idle/meeting (to restore)
    private var stateBeforePause: FlowState?

    public init() {}

    /// Called every 30 seconds by the app's tick loop.
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

        // Idle detection
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
            // Always return to normal — flow needs to be re-earned after being away
            scoreAboveFlowThresholdSince = nil
            scoreBelowExitThresholdSince = nil
            flowEntrySince = nil
            transition(to: .normal)
            // Don't return — fall through to update hysteresis with current score
        }

        // Skip flow calculations during break
        if state == .breakPrompted { return }

        // Update hysteresis counters
        updateHysteresis(flowScore: flowScore, now: now)

        // State transitions
        switch state {
        case .normal:
            if let since = scoreAboveFlowThresholdSince,
               now - since >= flowEntryDuration {
                flowEntrySince = now
                transition(to: .flow)
            }

        case .flow:
            if let since = scoreBelowExitThresholdSince,
               now - since >= flowExitDuration {
                flowEntrySince = nil
                transition(to: .normal)
            } else if let flowStart = flowEntrySince,
                      now - flowStart >= deepFlowDuration {
                transition(to: .deepFlow)
            }

        case .deepFlow:
            if let since = scoreBelowExitThresholdSince,
               now - since >= flowExitDuration {
                flowEntrySince = nil
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
        scoreAboveFlowThresholdSince = nil
        scoreBelowExitThresholdSince = nil
        transition(to: .normal)
    }

    // MARK: - Private

    private func updateHysteresis(flowScore: Double, now: TimeInterval) {
        if flowScore >= flowEntryThreshold {
            if scoreAboveFlowThresholdSince == nil {
                scoreAboveFlowThresholdSince = now
            }
            scoreBelowExitThresholdSince = nil
        } else if flowScore < flowExitThreshold {
            if scoreBelowExitThresholdSince == nil {
                scoreBelowExitThresholdSince = now
            }
            scoreAboveFlowThresholdSince = nil
        } else {
            // In the dead zone between thresholds — maintain current state
            // Reset whichever counter doesn't apply
            if state == .normal {
                scoreBelowExitThresholdSince = nil
            } else {
                scoreAboveFlowThresholdSince = nil
            }
        }
    }

    private func transition(to newState: FlowState) {
        guard newState != state else { return }
        let old = state
        state = newState
        onStateChange?(old, newState)
    }
}
