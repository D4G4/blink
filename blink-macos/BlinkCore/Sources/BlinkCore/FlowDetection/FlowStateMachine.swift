import Foundation

/// Detects idle and meeting states to pause the timer.
///
/// Flow/deep flow are NOT tracked continuously — the BreakDecisionEngine
/// evaluates work intensity once when the 20-minute timer fires. This avoids
/// false "In flow" states from casual computer use and keeps the menu bar
/// honest: it shows "Working" until a break decision is actually made.
public final class FlowStateMachine {
    public private(set) var state: FlowState = .normal
    public var onStateChange: ((_ old: FlowState, _ new: FlowState) -> Void)?

    /// Current sensitivity (0.4–0.9). Updated by the UI slider.
    public var sensitivity: Double = 0.7 {
        didSet { config = FlowConfig.config(forSensitivity: sensitivity) }
    }

    /// Derived config — recomputed when sensitivity changes.
    public private(set) var config: FlowConfig

    private var stateBeforePause: FlowState?

    // Duration thresholds
    public var idleThreshold: TimeInterval = 180  // 3 min idle = away

    public init() {
        self.config = FlowConfig.config(forSensitivity: sensitivity)
    }

    // MARK: - Tick

    /// Called every 30 seconds with current signals.
    /// Only handles idle/meeting transitions — flow detection is deferred
    /// to BreakDecisionEngine at timer end.
    public func tick(
        flowScore: Double,
        secondsSinceLastInput: TimeInterval,
        secondsSinceLastIntentionalInput: TimeInterval = 0,
        isMicActive: Bool,
        isCameraActive: Bool,
        now: TimeInterval
    ) {
        // Meeting — mic or camera active (instant)
        if isMicActive || isCameraActive {
            if state != .meeting {
                stateBeforePause = state
                transition(to: .meeting)
            }
            return
        }

        // Idle — no input for 3+ minutes (instant)
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
            transition(to: .normal)
        }
    }

    // MARK: - Public API

    public func enterBreakPrompted() {
        transition(to: .breakPrompted)
    }

    public func exitBreakPrompted() {
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
