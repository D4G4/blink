import Foundation

/// Configuration for break delivery behavior.
/// Derived from the user's sensitivity setting (0.4–0.9).
public struct FlowConfig: Sendable {

    /// How many times the timer can extend before forcing a break.
    /// Eye Health: 0 (always break at 20 min), Balanced: 1 (30 min cap), Deep Work: 2 (40 min cap).
    public let maxExtensions: Int

    /// Compute config from a sensitivity value (0.4–0.9).
    public static func config(forSensitivity sensitivity: Double) -> FlowConfig {
        let t = (sensitivity - 0.4) / (0.9 - 0.4)  // normalize to 0–1

        // Eye Health (t<0.2): 0, Balanced (t~0.5): 1, Deep Work (t>0.7): 2
        let extensions: Int
        if t < 0.2 {
            extensions = 0
        } else if t < 0.7 {
            extensions = 1
        } else {
            extensions = 2
        }

        return FlowConfig(maxExtensions: extensions)
    }
}
