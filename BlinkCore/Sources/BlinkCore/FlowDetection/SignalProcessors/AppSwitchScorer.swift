import Foundation

/// Scores flow based on app switching frequency.
/// Fewer switches = higher flow likelihood. Weight: 0.35
public struct AppSwitchScorer: Sendable {
    private static let windowSeconds: TimeInterval = 300 // 5 minutes

    public init() {}

    /// Returns a score from 0.0 (lots of switching) to 1.0 (no switching).
    public func score(switchTimestamps: [TimeInterval], now: TimeInterval) -> Double {
        let windowStart = now - Self.windowSeconds
        let recentCount = switchTimestamps.filter { $0 > windowStart }.count

        // 0 switches = 1.0, 1 = 0.85, 2 = 0.7, 3 = 0.5, 4 = 0.3, 5+ = 0.0
        switch recentCount {
        case 0: return 1.0
        case 1: return 0.85
        case 2: return 0.7
        case 3: return 0.5
        case 4: return 0.3
        default: return 0.0
        }
    }
}
