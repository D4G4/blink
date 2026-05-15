import Foundation

/// Manages flow state transitions using a configurable strategy.
/// All behavior is derived from `StrategyConfig` — no hardcoded logic per strategy.
public final class FlowStateMachine {
    public private(set) var state: FlowState = .normal
    public var onStateChange: ((_ old: FlowState, _ new: FlowState) -> Void)?

    /// Which detection strategy to use.
    public var strategy: FlowDetectionStrategy = .current

    /// Current sensitivity (0.4–0.9). Updated by the UI slider.
    public var sensitivity: Double = 0.7 {
        didSet { recomputeConfig() }
    }

    /// Derived config — recomputed when strategy or sensitivity changes.
    public private(set) var config: StrategyConfig

    // MARK: - V1 state (score-based)
    private var scoreAboveFlowThresholdSince: TimeInterval?
    private var scoreBelowExitThresholdSince: TimeInterval?

    // MARK: - V2/V3 state (activity-gap)
    private var continuousActivityStart: TimeInterval?

    // MARK: - Shared state
    private var flowEntrySince: TimeInterval?
    private var stateBeforePause: FlowState?

    // Duration thresholds (not strategy-dependent)
    public var flowEntryDuration: TimeInterval = 180     // 3 minutes
    public var flowExitDuration: TimeInterval = 120      // 2 minutes (V1 hysteresis)
    public var deepFlowDuration: TimeInterval = 900      // 15 minutes in flow
    public var idleThreshold: TimeInterval = 180          // 3 min idle = away

    public init() {
        self.config = strategy.config(forSensitivity: sensitivity)
    }

    private func recomputeConfig() {
        config = strategy.config(forSensitivity: sensitivity)
    }

    // MARK: - Tick

    /// Called every 30 seconds.
    /// - `flowScore`: composite score (V1 uses this)
    /// - `secondsSinceLastInput`: any input (idle detection, V2 flow)
    /// - `secondsSinceLastIntentionalInput`: keyboard+clicks+scroll (V3 flow)
    public func tick(
        flowScore: Double,
        secondsSinceLastInput: TimeInterval,
        secondsSinceLastIntentionalInput: TimeInterval = 0,
        isMicActive: Bool,
        isCameraActive: Bool,
        now: TimeInterval
    ) {
        // Meeting — same for all strategies
        if isMicActive || isCameraActive {
            if state != .meeting {
                stateBeforePause = state
                transition(to: .meeting)
            }
            return
        }

        // Idle — always uses any input
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
            resetFlowTracking()
            transition(to: .normal)
        }

        if state == .breakPrompted { return }

        // Dispatch to strategy
        switch strategy {
        case .scoreBased:
            tickScoreBased(flowScore: flowScore, now: now)
        case .breakDecisionEngine:
            // V2: FlowStateMachine still tracks state for display purposes
            // but break decisions are made by BreakDecisionEngine in AppState
            tickActivityGapTwoTier(idleTime: secondsSinceLastIntentionalInput, now: now)
        }
    }

    // MARK: - V1: Score-based

    private func tickScoreBased(flowScore: Double, now: TimeInterval) {
        let entryThreshold = config.flowEntryScoreThreshold
        let exitThreshold = config.flowExitScoreThreshold

        if flowScore >= entryThreshold {
            scoreAboveFlowThresholdSince = scoreAboveFlowThresholdSince ?? now
            scoreBelowExitThresholdSince = nil
        } else if flowScore < exitThreshold {
            scoreBelowExitThresholdSince = scoreBelowExitThresholdSince ?? now
            scoreAboveFlowThresholdSince = nil
        } else {
            // Dead zone — maintain current state
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
            } else if let start = flowEntrySince,
                      now - start >= deepFlowDuration {
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

    // MARK: - V2/V3: Activity gap

    private func tickActivityGap(idleTime: TimeInterval, now: TimeInterval) {
        let isActive = idleTime < config.gapTolerance

        if isActive {
            continuousActivityStart = continuousActivityStart ?? now
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
            } else if let start = flowEntrySince,
                      now - start >= deepFlowDuration {
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

    // MARK: - V3: Two-tier activity gap

    /// Entry uses stricter tolerance (must be actively typing).
    /// Maintenance uses 1.5x tolerance (clicks/scroll during AI wait keep flow alive).
    private func tickActivityGapTwoTier(idleTime: TimeInterval, now: TimeInterval) {
        let inFlow = state == .flow || state == .deepFlow
        let tolerance = inFlow ? config.maintenanceGapTolerance : config.entryGapTolerance
        let isActive = idleTime < tolerance

        if isActive {
            continuousActivityStart = continuousActivityStart ?? now
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
            } else if let start = flowEntrySince,
                      now - start >= deepFlowDuration {
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
