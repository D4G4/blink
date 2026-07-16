import Foundation

/// 1-up / 3-down adaptive staircase for measuring contrast thresholds.
///
/// Converges on the **79.4%-correct** point — the target of the transformed
/// up/down rule (Levitt 1971) and what the validated Gabor perceptual-learning
/// protocols use (Polat et al. 2004; GlassesOff). Three correct responses in a
/// row make the task harder (lower contrast); a single miss makes it easier.
///
/// Contrast is stepped in the **log domain** (multiplicatively): a fixed
/// multiplicative factor keeps resolution uniform across the contrast range,
/// where a fixed *linear* step is coarse near threshold and needlessly fine up
/// high. The step halves at each reversal so the track homes in, and the
/// threshold is the geometric mean of the later reversals — the correct centre
/// for log-spaced values.
final class AdaptiveStaircase: ObservableObject {
    @Published private(set) var currentContrast: Double

    private var consecutiveCorrect = 0
    private var logStep: Double                 // current step, log10 contrast units
    private var lastDirection: Direction?
    private var reversals: [Double] = []        // contrast at each turnaround
    private(set) var trialResults: [(contrast: Double, correct: Bool)] = []

    private enum Direction { case up, down }

    /// Correct responses in a row required to step down (harder). 3 → 79.4%.
    private let downAfter = 3
    private let minContrast: Double = 0.005
    private let maxContrast: Double = 1.0
    private let initialLogStep: Double
    /// Finest step near convergence (~0.03 log10 ≈ ×1.07).
    private let minLogStep: Double = 0.03

    /// - Parameters:
    ///   - startContrast: where the track begins (well above threshold).
    ///   - initialLogStep: first step size in log10 units (0.15 ≈ ×1.41).
    init(startContrast: Double = 0.5, initialLogStep: Double = 0.15) {
        self.currentContrast = startContrast
        self.initialLogStep = initialLogStep
        self.logStep = initialLogStep
    }

    func recordResponse(correct: Bool) {
        trialResults.append((contrast: currentContrast, correct: correct))

        if correct {
            consecutiveCorrect += 1
            guard consecutiveCorrect >= downAfter else { return }
            consecutiveCorrect = 0
            step(.down)
        } else {
            consecutiveCorrect = 0
            step(.up)
        }
    }

    /// Move one step; when the direction flips, record the turnaround contrast
    /// as a reversal and halve the step for finer resolution.
    private func step(_ direction: Direction) {
        if let last = lastDirection, last != direction {
            reversals.append(currentContrast)
            logStep = max(logStep * 0.5, minLogStep)
        }
        let factor = pow(10.0, direction == .down ? -logStep : logStep)
        currentContrast = min(max(currentContrast * factor, minContrast), maxContrast)
        lastDirection = direction
    }

    /// Geometric-mean threshold over the settled reversals (first one dropped,
    /// last 6 kept). `nil` until at least two reversals exist.
    func threshold() -> Double? {
        guard reversals.count >= 2 else { return nil }
        let settled = Array(reversals.dropFirst().suffix(6))
        guard !settled.isEmpty else { return nil }
        let meanLog = settled.map { log10($0) }.reduce(0, +) / Double(settled.count)
        return pow(10.0, meanLog)
    }

    var reversalCount: Int { reversals.count }

    /// Reset the track. `startContrast` lets a session begin near the previous
    /// session's threshold (with headroom) instead of always at 0.5, so the
    /// staircase spends fewer trials descending from scratch.
    func reset(startContrast: Double = 0.5) {
        currentContrast = min(max(startContrast, minContrast), maxContrast)
        logStep = initialLogStep
        consecutiveCorrect = 0
        lastDirection = nil
        reversals = []
        trialResults = []
    }
}
