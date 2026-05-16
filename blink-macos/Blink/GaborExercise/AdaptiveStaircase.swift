import Foundation

/// 2-down-1-up adaptive staircase for measuring contrast thresholds.
///
/// Converges to the 70.7% correct threshold — a standard psychophysical measurement.
/// Step size halves at each reversal for finer resolution as the staircase homes in.
final class AdaptiveStaircase: ObservableObject {
    @Published private(set) var currentContrast: Double

    private var consecutiveCorrect = 0
    private var stepSize: Double
    private var lastDirection: Direction?
    private var reversals: [Double] = []
    private(set) var trialResults: [(contrast: Double, correct: Bool)] = []

    private enum Direction { case up, down }

    private let minContrast: Double = 0.01
    private let maxContrast: Double = 1.0
    private let minStep: Double = 0.005

    init(startContrast: Double = 0.5, initialStep: Double = 0.05) {
        self.currentContrast = startContrast
        self.stepSize = initialStep
    }

    func recordResponse(correct: Bool) {
        trialResults.append((contrast: currentContrast, correct: correct))

        if correct {
            consecutiveCorrect += 1
            if consecutiveCorrect >= 2 {
                consecutiveCorrect = 0
                let newDirection = Direction.down
                currentContrast = max(currentContrast - stepSize, minContrast)
                if lastDirection == .up {
                    reversals.append(currentContrast)
                    stepSize = max(stepSize * 0.5, minStep)
                }
                lastDirection = newDirection
            }
        } else {
            consecutiveCorrect = 0
            let newDirection = Direction.up
            currentContrast = min(currentContrast + stepSize, maxContrast)
            if lastDirection == .down {
                reversals.append(currentContrast)
                stepSize = max(stepSize * 0.5, minStep)
            }
            lastDirection = newDirection
        }
    }

    /// Estimated contrast threshold based on reversal values.
    /// Returns nil if insufficient data.
    func threshold() -> Double? {
        if reversals.count >= 6 {
            let last6 = reversals.suffix(6)
            return last6.reduce(0, +) / Double(last6.count)
        } else if reversals.count >= 2 {
            return reversals.reduce(0, +) / Double(reversals.count)
        }
        return nil
    }

    var reversalCount: Int { reversals.count }

    func reset() {
        currentContrast = 0.5
        stepSize = 0.05
        consecutiveCorrect = 0
        lastDirection = nil
        reversals = []
        trialResults = []
    }
}
