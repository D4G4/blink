import Foundation

/// Learns the user's natural break rhythm and adjusts timer duration.
/// Analyzes which break intervals the user actually complies with.
public final class AdaptiveTimingEngine {
    private var acceptedIntervals: [TimeInterval] = []
    private static let maxHistory = 50
    private static let minInterval: TimeInterval = 900   // 15 minutes
    private static let maxInterval: TimeInterval = 2700  // 45 minutes

    public init() {}

    /// Record that a break was accepted at this interval since last break.
    public func recordAcceptedBreak(intervalSinceLastBreak: TimeInterval) {
        acceptedIntervals.append(intervalSinceLastBreak)
        if acceptedIntervals.count > Self.maxHistory {
            acceptedIntervals.removeFirst()
        }
    }

    /// Returns the suggested base timer duration based on learned behavior.
    /// Returns nil if not enough data to make a recommendation.
    public func suggestedDuration() -> TimeInterval? {
        guard acceptedIntervals.count >= 10 else { return nil }

        // Use the median of recent accepted intervals
        let sorted = acceptedIntervals.sorted()
        let median = sorted[sorted.count / 2]

        return min(Self.maxInterval, max(Self.minInterval, median))
    }

    /// Load saved intervals (from persistence).
    public func load(intervals: [TimeInterval]) {
        acceptedIntervals = Array(intervals.suffix(Self.maxHistory))
    }

    /// Current intervals for persistence.
    public func savedIntervals() -> [TimeInterval] {
        acceptedIntervals
    }
}
