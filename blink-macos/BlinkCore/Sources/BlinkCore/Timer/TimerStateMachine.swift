import Foundation

/// Manages the break countdown timer.
/// Counts down every second. Pauses when idle or in a meeting.
public final class TimerStateMachine {
    public static let defaultDuration: TimeInterval = 1200  // 20 minutes

    public private(set) var remainingSeconds: TimeInterval
    public private(set) var isPaused: Bool = false

    public var onBreakDue: (() -> Void)?

    public init() {
        self.remainingSeconds = Self.defaultDuration
    }

    /// Total duration for progress bar calculation.
    public var timerDuration: TimeInterval { Self.defaultDuration }

    /// Progress from 0.0 (just started) to 1.0 (break due).
    public var progress: Double {
        guard Self.defaultDuration > 0 else { return 1.0 }
        return max(0, min(1.0, 1.0 - remainingSeconds / Self.defaultDuration))
    }

    /// Called every second to advance the timer.
    public func tick(flowState: FlowState, deltaSeconds: TimeInterval) {
        if flowState == .idle || flowState == .meeting {
            isPaused = true
            return
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
        remainingSeconds = Self.defaultDuration
        isPaused = false
    }

    /// Reset with a specific duration (for extensions).
    public func reset(duration: TimeInterval) {
        remainingSeconds = duration
        isPaused = false
    }
}
