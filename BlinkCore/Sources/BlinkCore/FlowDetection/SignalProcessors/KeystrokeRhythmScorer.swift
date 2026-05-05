import Foundation

/// Scores flow based on keystroke rate and rhythm consistency.
/// Sustained, rhythmic typing = higher score. Weight: 0.25
public struct KeystrokeRhythmScorer: Sendable {
    private static let windowSeconds: TimeInterval = 120 // 2 minutes

    public init() {}

    /// Returns a score from 0.0 (no/sporadic typing) to 1.0 (sustained rhythmic typing).
    public func score(keystrokeTimestamps: [TimeInterval], now: TimeInterval) -> Double {
        let windowStart = now - Self.windowSeconds
        let recent = keystrokeTimestamps.filter { $0 > windowStart }

        guard recent.count >= 5 else { return 0.0 }

        // Keys per minute
        let kpm = Double(recent.count) / (Self.windowSeconds / 60.0)
        let kpmScore = min(kpm / 80.0, 1.0) // 80+ KPM = max score

        // Inter-keystroke interval variance (lower = more rhythmic)
        let intervals = zip(recent.dropFirst(), recent).map { $0 - $1 }
        // Filter out think-pauses (>5s) — those are normal in flow
        let typingIntervals = intervals.filter { $0 <= 5.0 }

        guard typingIntervals.count >= 3 else { return kpmScore * 0.5 }

        let mean = typingIntervals.reduce(0, +) / Double(typingIntervals.count)
        let variance = typingIntervals.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(typingIntervals.count)
        let cv = mean > 0 ? sqrt(variance) / mean : 1.0 // coefficient of variation

        // Low CV = rhythmic (good). CV > 2.0 = sporadic (bad)
        let rhythmScore = max(0, min(1.0, 1.0 - (cv - 0.3) / 1.7))

        return kpmScore * 0.6 + rhythmScore * 0.4
    }
}
