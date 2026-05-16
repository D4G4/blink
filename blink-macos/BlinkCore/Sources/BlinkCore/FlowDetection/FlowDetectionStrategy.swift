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

    /// Compute config from a sensitivity value (0.4–0.9).
    /// Higher sensitivity → more generous gap tolerance → easier to enter/maintain flow.
    public static func config(forSensitivity sensitivity: Double) -> FlowConfig {
        let t = (sensitivity - 0.4) / (0.9 - 0.4)  // normalize to 0–1
        // Gap: 8–25s (at balanced t=0.5: 16.5s)
        let gap = 8.0 + t * 17.0

        return FlowConfig(
            flowEntryScoreThreshold: 0.35,
            entryGapTolerance: gap,
            maintenanceGapTolerance: gap * 1.5
        )
    }
}
