import Foundation

/// Manages flow state transitions using a configurable strategy.
/// See `FlowDetectionStrategy` for documentation of each approach.
public final class FlowStateMachine {
    public private(set) var state: FlowState = .normal
    public var onStateChange: ((_ old: FlowState, _ new: FlowState) -> Void)?

    /// Which detection strategy to use. Change this to switch between V1/V2/V3.
    public var strategy: FlowDetectionStrategy = .current

    // MARK: - V1 state (score-based)
    private var scoreAboveFlowThresholdSince: TimeInterval?
    private var scoreBelowExitThresholdSince: TimeInterval?

    // MARK: - V2/V3 state (activity-gap)
    private var continuousActivityStart: TimeInterval?

    // MARK: - Shared state
    private var flowEntrySince: TimeInterval?
    private var stateBeforePause: FlowState?

    // Threshold defaults
    public static let defaultFlowEntryThreshold: Double = 0.7
    public static let defaultFlowExitThreshold: Double = 0.4
    public static let defaultFlowEntryDuration: TimeInterval = 180    // 3 minutes
    public static let defaultFlowExitDuration: TimeInterval = 120     // 2 minutes (V1 only)
    public static let defaultDeepFlowDuration: TimeInterval = 900     // 15 minutes in flow
    public static let defaultIdleThreshold: TimeInterval = 180        // 3 min idle = away

    // Configurable thresholds
    public var flowEntryThreshold: Double = defaultFlowEntryThreshold
    public var flowExitThreshold: Double = defaultFlowExitThreshold
    public var flowEntryDuration: TimeInterval = defaultFlowEntryDuration
    public var flowExitDuration: TimeInterval = defaultFlowExitDuration
    public var deepFlowDuration: TimeInterval = defaultDeepFlowDuration
    public var idleThreshold: TimeInterval = defaultIdleThreshold

    public init() {}

    /// Gap tolerance in seconds for V2/V3. Derived from sensitivity slider (0.4–0.9).
    public var gapTolerance: TimeInterval {
        let t = (flowEntryThreshold - 0.4) / (0.9 - 0.4)
        return 15 + t * 75
    }

    // MARK: - Tick

    /// Called every 30 seconds by the app's tick loop.
    /// - `flowScore`: composite score from FlowScoreCalculator (used by V1)
    /// - `secondsSinceLastInput`: any input including mouse moves (used for idle detection, V2 flow)
    /// - `secondsSinceLastIntentionalInput`: keyboard + clicks + scroll, no mouse moves (used by V3 flow)
    /// - `isMicActive`/`isCameraActive`: meeting detection
    public func tick(
        flowScore: Double,
        secondsSinceLastInput: TimeInterval,
        secondsSinceLastIntentionalInput: TimeInterval = 0,
        isMicActive: Bool,
        isCameraActive: Bool,
        now: TimeInterval
    ) {
        // Meeting detection — same for all strategies
        if isMicActive || isCameraActive {
            if state != .meeting {
                stateBeforePause = state
                transition(to: .meeting)
            }
            return
        }

        // Idle detection — always uses any input (including mouse moves)
        if secondsSinceLastInput >= idleThreshold {
            if state != .idle {
                stateBeforePause = state
                transition(to: .idle)
            }
            return
        }

        // Returning from idle/meeting — same for all strategies
        if state == .idle || state == .meeting {
            stateBeforePause = nil
            resetFlowTracking()
            transition(to: .normal)
        }

        if state == .breakPrompted { return }

        // Strategy-specific flow detection
        switch strategy {
        case .scoreBased:
            tickV1ScoreBased(flowScore: flowScore, now: now)
        case .activityGapAnyInput:
            tickV2ActivityGap(idleTime: secondsSinceLastInput, now: now)
        case .intentionalWithEscalation:
            tickV3Intentional(idleTime: secondsSinceLastIntentionalInput, now: now)
        }
    }

    // MARK: - V1: Score-based

    private func tickV1ScoreBased(flowScore: Double, now: TimeInterval) {
        // Update hysteresis counters
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
            // Dead zone between thresholds — maintain current state
            if state == .normal {
                scoreBelowExitThresholdSince = nil
            } else {
                scoreAboveFlowThresholdSince = nil
            }
        }

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

    // MARK: - V2: Activity gap (any input)

    private func tickV2ActivityGap(idleTime: TimeInterval, now: TimeInterval) {
        let isActive = idleTime < gapTolerance

        if isActive {
            if continuousActivityStart == nil {
                continuousActivityStart = now
            }
        } else {
            continuousActivityStart = nil
        }

        switch state {
        case .normal:
            if let start = continuousActivityStart,
               now - start >= flowEntryDuration {
                flowEntrySince = now
                transition(to: .flow)
            }

        case .flow:
            if !isActive {
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

    // MARK: - V3: Intentional input with escalation (same gap logic, different input)

    private func tickV3Intentional(idleTime: TimeInterval, now: TimeInterval) {
        // Same gap logic as V2 but uses intentional input (keyboard + clicks + scroll)
        // The escalation logic lives in AppState, not here
        tickV2ActivityGap(idleTime: idleTime, now: now)
    }

    // MARK: - Public API

    public func enterBreakPrompted() {
        transition(to: .breakPrompted)
    }

    public func exitBreakPrompted() {
        resetFlowTracking()
        transition(to: .normal)
    }

    // MARK: - Private

    private func resetFlowTracking() {
        flowEntrySince = nil
        continuousActivityStart = nil
        scoreAboveFlowThresholdSince = nil
        scoreBelowExitThresholdSince = nil
    }

    private func transition(to newState: FlowState) {
        guard newState != state else { return }
        let old = state
        state = newState
        onStateChange?(old, newState)
    }
}
