import Foundation

public enum BreakCompliance: String, Codable, Sendable {
    case taken      // user paused for 20+ seconds within 60s of prompt
    case dismissed  // clicked dismiss within 5s
    case delayed    // took break but after >60s
    case ignored    // never responded, gave up after 5min
}

public struct BreakRecord: Codable, Sendable {
    public let promptedAt: Date
    public let respondedAt: Date?
    public let flowStateWhenPrompted: FlowState
    public let flowScore: Double
    public let compliance: BreakCompliance
    public let breakDurationSeconds: TimeInterval?

    public init(
        promptedAt: Date,
        respondedAt: Date?,
        flowStateWhenPrompted: FlowState,
        flowScore: Double,
        compliance: BreakCompliance,
        breakDurationSeconds: TimeInterval?
    ) {
        self.promptedAt = promptedAt
        self.respondedAt = respondedAt
        self.flowStateWhenPrompted = flowStateWhenPrompted
        self.flowScore = flowScore
        self.compliance = compliance
        self.breakDurationSeconds = breakDurationSeconds
    }
}
