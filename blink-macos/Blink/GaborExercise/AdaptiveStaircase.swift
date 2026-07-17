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
    private let minContrast: Double
    private let maxContrast: Double
    private let initialLogStep: Double
    /// Finest step near convergence (~0.03 log10 ≈ ×1.07).
    private let minLogStep: Double = 0.03

    /// - Parameters:
    ///   - startContrast: where the track begins (well above threshold).
    ///   - initialLogStep: first step size in log10 units (0.25 ≈ ×1.78). Large
    ///     early steps descend to threshold fast; the step halves at each
    ///     reversal for fine resolution once it is homing in.
    /// The same 1-up/3-down log staircase also drives the crowding exercise's
    /// dimensionless spacing ratio b (min/max then bound b, not contrast); the
    /// "down = harder" direction is already correct there (smaller b = harder).
    init(startContrast: Double = 0.5, initialLogStep: Double = 0.25,
         minContrast: Double = 0.005, maxContrast: Double = 1.0) {
        self.currentContrast = startContrast
        self.initialLogStep = initialLogStep
        self.logStep = initialLogStep
        self.minContrast = minContrast
        self.maxContrast = maxContrast
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

    /// Reversals to discard before averaging — the early turnarounds are taken
    /// at the large, still-halving step and sit far above the settled threshold,
    /// so folding them in biases the estimate high (García-Pérez 1998; Levitt
    /// 1971). Only reversals from here on are near the final minLogStep.
    private let discardReversals = 2
    /// Minimum settled reversals before a threshold is trustworthy enough to show.
    private let minSettledReversals = 4

    /// Geometric-mean contrast threshold over the SETTLED reversals: the first
    /// `discardReversals` (coarse-step) turnarounds are dropped and up to the
    /// last 8 of the remainder are averaged in the log domain. Returns `nil`
    /// until at least `minSettledReversals` settled reversals exist, so a noisy
    /// early estimate is never reported as a threshold.
    func threshold() -> Double? {
        let settled = reversals.dropFirst(discardReversals)
        guard settled.count >= minSettledReversals else { return nil }
        let used = Array(settled.suffix(8))
        let meanLog = used.map { log10($0) }.reduce(0, +) / Double(used.count)
        return pow(10.0, meanLog)
    }

    var reversalCount: Int { reversals.count }
    /// Whether enough settled reversals have accrued for `threshold()` to report.
    var hasSettledThreshold: Bool { reversals.count >= discardReversals + minSettledReversals }

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
