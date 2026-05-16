import Foundation

/// Manages flow state transitions based on activity gaps and flow score.
///
/// Entry requires BOTH:
/// - Continuous intentional input (gap < tolerance) for 3+ minutes
/// - Flow score above a minimum threshold (prevents normal use from registering as flow)
///
/// Maintenance is more lenient — only checks the gap (allows reading/thinking pauses).
/// Deep flow triggers after 15 minutes in flow (purely duration-based).
public final class FlowStateMachine {
    public private(set) var state: FlowState = .normal
    public var onStateChange: ((_ old: FlowState, _ new: FlowState) -> Void)?

    /// Current sensitivity (0.4–0.9). Updated by the UI slider.
    public var sensitivity: Double = 0.7 {
        didSet { config = FlowConfig.config(forSensitivity: sensitivity) }
    }

    /// Derived config — recomputed when sensitivity changes.
    public private(set) var config: FlowConfig

    // Activity tracking
    private var continuousActivityStart: TimeInterval?
    private var flowEntrySince: TimeInterval?
    private var stateBeforePause: FlowState?

    // Duration thresholds
    public var flowEntryDuration: TimeInterval = 180     // 3 minutes
    public var deepFlowDuration: TimeInterval = 900      // 15 minutes in flow
    public var idleThreshold: TimeInterval = 180          // 3 min idle = away

    public init() {
        self.config = FlowConfig.config(forSensitivity: sensitivity)
    }

    // MARK: - Tick

    /// Called every 30 seconds with current signals.
    public func tick(
        flowScore: Double,
        secondsSinceLastInput: TimeInterval,
        secondsSinceLastIntentionalInput: TimeInterval = 0,
        isMicActive: Bool,
        isCameraActive: Bool,
        now: TimeInterval
    ) {
        // Meeting — mic or camera active
        if isMicActive || isCameraActive {
            if state != .meeting {
                stateBeforePause = state
                transition(to: .meeting)
            }
            return
        }

        // Idle — no input at all for 3+ minutes
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

        // Flow detection: two-tier gap tolerance + score check for entry
        let inFlow = state == .flow || state == .deepFlow
        let tolerance = inFlow ? config.maintenanceGapTolerance : config.entryGapTolerance
        let isActive: Bool
        if inFlow {
            // Maintenance: only gap check
            isActive = secondsSinceLastIntentionalInput < tolerance
        } else {
            // Entry: gap check AND minimum flow score
            isActive = secondsSinceLastIntentionalInput < tolerance
                && flowScore >= config.flowEntryScoreThreshold
        }

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
    }

    private func transition(to newState: FlowState) {
        guard newState != state else { return }
        let old = state
        state = newState
        onStateChange?(old, newState)
    }
}
