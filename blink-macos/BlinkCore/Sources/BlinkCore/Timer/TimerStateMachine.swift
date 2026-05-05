import Foundation

/// Manages the break countdown timer, adapting duration based on flow state.
public final class TimerStateMachine {
    public static let defaultNormalDuration: TimeInterval = 1200    // 20 minutes
    public static let defaultFlowDuration: TimeInterval = 1800      // 30 minutes
    public static let defaultDeepFlowDuration: TimeInterval = 2400  // 40 minutes

    public private(set) var remainingSeconds: TimeInterval
    public private(set) var isPaused: Bool = false

    public var onBreakDue: (() -> Void)?

    // Duration per flow state
    public var normalDuration: TimeInterval = defaultNormalDuration
    public var flowDuration: TimeInterval = defaultFlowDuration
    public var deepFlowDuration: TimeInterval = defaultDeepFlowDuration

    private var currentFlowState: FlowState = .normal

    public init() {
        self.remainingSeconds = Self.defaultNormalDuration
    }

    /// The total duration for the current flow state.
    public var timerDuration: TimeInterval {
        duration(for: currentFlowState)
    }

    /// Progress from 0.0 (just started) to 1.0 (break due).
    public var progress: Double {
        let total = timerDuration
        guard total > 0 else { return 1.0 }
        return max(0, min(1.0, 1.0 - remainingSeconds / total))
    }

    /// Called every second (or at tick intervals) to advance the timer.
    public func tick(flowState: FlowState, deltaSeconds: TimeInterval) {
        // Pause during idle or meeting
        if flowState == .idle || flowState == .meeting {
            isPaused = true
            return
        }

        // If flow state changed, adjust remaining time proportionally
        if flowState != currentFlowState && flowState != .breakPrompted {
            let oldDuration = duration(for: currentFlowState)
            let newDuration = duration(for: flowState)

            if oldDuration > 0 {
                let elapsed = oldDuration - remainingSeconds
                let elapsedRatio = elapsed / oldDuration
                remainingSeconds = newDuration * (1.0 - elapsedRatio)
            }

            currentFlowState = flowState
        }

        isPaused = false

        guard flowState != .breakPrompted else { return }

        guard remainingSeconds > 0 else { return }

        remainingSeconds -= deltaSeconds

        if remainingSeconds <= 0 {
            remainingSeconds = 0
            onBreakDue?()
        }
    }

    /// Reset timer after a break is taken.
    public func resetAfterBreak() {
        currentFlowState = .normal
        remainingSeconds = normalDuration
        isPaused = false
    }

    /// Reset with a specific duration (for adaptive timing).
    public func reset(duration: TimeInterval) {
        remainingSeconds = duration
        isPaused = false
    }

    /// Pause the timer manually.
    public func pause() {
        isPaused = true
    }

    /// Resume the timer manually.
    public func resume() {
        isPaused = false
    }

    private func duration(for state: FlowState) -> TimeInterval {
        switch state {
        case .flow: return flowDuration
        case .deepFlow: return deepFlowDuration
        default: return normalDuration
        }
    }
}
