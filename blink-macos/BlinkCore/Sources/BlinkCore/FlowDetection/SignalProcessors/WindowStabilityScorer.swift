import Foundation

/// Scores flow based on how stable the focused window is.
/// Fewer window title changes = higher score. Weight: 0.10
public struct WindowStabilityScorer: Sendable {
    private static let windowSeconds: TimeInterval = 300 // 5 minutes

    public init() {}

    /// Returns a score from 0.0 (rapid switching) to 1.0 (stable window).
    public func score(titleChangeTimestamps: [TimeInterval], now: TimeInterval) -> Double {
        let windowStart = now - Self.windowSeconds
        let recentChanges = titleChangeTimestamps.filter { $0 > windowStart }.count

        // 0 changes = 1.0, linear decrease, 10+ changes = 0.0
        return max(0.0, 1.0 - Double(recentChanges) / 10.0)
    }
}
