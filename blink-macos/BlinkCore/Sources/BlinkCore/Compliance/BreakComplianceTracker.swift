import Foundation

/// Tracks whether the user actually takes a break after being prompted.
public final class BreakComplianceTracker {
    public var onBreakRecorded: ((BreakRecord) -> Void)?

    private var promptTime: Date?
    private var promptFlowState: FlowState?
    private var promptFlowScore: Double?
    private var maxWaitSeconds: TimeInterval = 300 // 5 minutes

    public init() {}

    /// Called when a break prompt is shown.
    public func breakPrompted(
        at time: Date,
        flowState: FlowState,
        flowScore: Double
    ) {
        promptTime = time
        promptFlowState = flowState
        promptFlowScore = flowScore
    }

    /// Called when the user dismisses the break prompt.
    public func breakDismissed(at time: Date) {
        guard let promptTime, let flowState = promptFlowState, let score = promptFlowScore else { return }

        let elapsed = time.timeIntervalSince(promptTime)
        let compliance: BreakCompliance = elapsed < 5 ? .dismissed : .delayed

        let record = BreakRecord(
            promptedAt: promptTime,
            respondedAt: time,
            flowStateWhenPrompted: flowState,
            flowScore: score,
            compliance: compliance,
            breakDurationSeconds: nil
        )
        onBreakRecorded?(record)
        reset()
    }

    /// Called when idle is detected after a break prompt (user actually looked away).
    public func breakTaken(at time: Date, idleDuration: TimeInterval) {
        guard let promptTime, let flowState = promptFlowState, let score = promptFlowScore else { return }

        let elapsed = time.timeIntervalSince(promptTime)
        let compliance: BreakCompliance = elapsed <= 60 ? .taken : .delayed

        let record = BreakRecord(
            promptedAt: promptTime,
            respondedAt: time,
            flowStateWhenPrompted: flowState,
            flowScore: score,
            compliance: compliance,
            breakDurationSeconds: idleDuration
        )
        onBreakRecorded?(record)
        reset()
    }

    /// Called when max wait time is exceeded without any response.
    public func breakIgnored(at time: Date) {
        guard let promptTime, let flowState = promptFlowState, let score = promptFlowScore else { return }

        let record = BreakRecord(
            promptedAt: promptTime,
            respondedAt: nil,
            flowStateWhenPrompted: flowState,
            flowScore: score,
            compliance: .ignored,
            breakDurationSeconds: nil
        )
        onBreakRecorded?(record)
        reset()
    }

    public var isTrackingBreak: Bool {
        promptTime != nil
    }

    private func reset() {
        promptTime = nil
        promptFlowState = nil
        promptFlowScore = nil
    }
}
