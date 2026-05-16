import Foundation

/// Configuration for flow detection and break delivery.
/// Derived from the user's sensitivity setting (0.4–0.9).
public struct FlowConfig: Sendable {

    /// Minimum flow score required to start building toward flow entry.
    /// Prevents normal computer use (score 0.2) from registering as flow.
    public let flowEntryScoreThreshold: Double

    /// Max seconds since last intentional input (keyboard/click/scroll) to count
    /// as "active" when building toward flow entry.
    public let entryGapTolerance: TimeInterval

    /// More forgiving gap tolerance once already in flow. Allows reading/thinking
    /// pauses without dropping flow state immediately.
    public let maintenanceGapTolerance: TimeInterval

    /// How many times the timer can extend before forcing a break.
    /// Eye Health: 0 (always break at 20 min), Balanced: 1 (30 min cap), Deep Work: 2 (40 min cap).
    public let maxExtensions: Int

    /// Compute config from a sensitivity value (0.4–0.9).
    /// Higher sensitivity → more generous gap tolerance → easier to enter/maintain flow.
    public static func config(forSensitivity sensitivity: Double) -> FlowConfig {
        let t = (sensitivity - 0.4) / (0.9 - 0.4)  // normalize to 0–1
        // Gap: 8–25s (at balanced t=0.5: 16.5s)
        let gap = 8.0 + t * 17.0

        // Eye Health (t<0.2): 0, Balanced (t~0.5): 1, Deep Work (t>0.8): 2
        let extensions: Int
        if t < 0.2 {
            extensions = 0
        } else if t < 0.7 {
            extensions = 1
        } else {
            extensions = 2
        }

        return FlowConfig(
            flowEntryScoreThreshold: 0.35,
            entryGapTolerance: gap,
            maintenanceGapTolerance: gap * 1.5,
            maxExtensions: extensions
        )
    }
}
