import Foundation
import SwiftUI

enum ExerciseType: String, CaseIterable, Identifiable {
    /// Primary: single-Gabor temporal two-interval detection.
    case detection = "Spot the Flash"
    /// Advanced: same task with two bold collinear flankers bracketing the target.
    case flanker = "Flanker Focus"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .detection: "sparkle.magnifyingglass"
        case .flanker: "circle.grid.3x3"
        }
    }

    var headline: String {
        switch self {
        case .detection:
            "Which flash held the pattern?"
        case .flanker:
            "Focus through bold distractions"
        }
    }

    var explanation: String {
        switch self {
        case .detection:
            "Two brief flashes, one after the other. Only one holds a faint striped pattern; the other is plain gray. Spot which flash had it."
        case .flanker:
            "Like Spot the Flash, but two bold striped patches bracket the center of both flashes. Only one flash also hides a faint pattern between them."
        }
    }

    var howToPlay: String {
        switch self {
        case .detection:
            "Watch both flashes, then choose First or Second — whichever held the pattern."
        case .flanker:
            "Ignore the two bold patches. Choose First or Second — whichever flash held the faint center pattern."
        }
    }

    /// Honest, plain-English "how this helps" — describes the visual skill the
    /// task exercises, framed as a wellness activity. Never a medical/vision-
    /// improvement claim (see the disclaimer).
    var benefit: String {
        switch self {
        case .detection:
            "Exercises your contrast sensitivity — seeing faint, low-contrast detail. A wellness activity done little-and-often, not a medical treatment; results vary."
        case .flanker:
            "Exercises pulling a faint target out of nearby clutter (lateral masking). A wellness activity, not a medical treatment; benefits build slowly."
        }
    }
}

enum ExercisePhase {
    case disclaimer
    case ready
    case instructions
    case presenting
    case feedback(correct: Bool)
    case complete
}

/// The timed sequence within a single trial. The `interval`/`mask` argument is
/// the flash number (1 or 2). A trial runs:
/// fixation → interval(1) → mask(1) → gap → interval(2) → mask(2) → response.
enum TrialStage: Equatable {
    case fixation
    case interval(Int)
    case mask(Int)
    case gap
    case response
}

/// Drives a Gabor exercise session — manages trials, scoring, and the adaptive staircase.
final class GaborExerciseState: ObservableObject {
    @Published var exerciseType: ExerciseType = .detection
    @Published var phase: ExercisePhase = .disclaimer
    @Published var currentTrial: Int = 0
    @Published var score: Int = 0

    /// Where we are in the current trial's timed flash sequence.
    @Published var stage: TrialStage = .fixation

    // Per-trial randomized state.
    /// Which flash (1 or 2) holds the target patch this trial.
    @Published var targetInterval: Int = 1
    /// Random carrier orientation (radians) for the target. The detection task
    /// does NOT depend on it — it just keeps the stimulus from being identical
    /// every trial.
    @Published var trialOrientation: Double = 0

    /// One spatial frequency (cycles/deg) is used for the whole session,
    /// rotating between sessions to avoid within-session roving.
    @Published var sessionSF: Double = 3.0

    // MARK: - Timing constants (milliseconds)

    static let fixationMs = 500
    /// Single-Gabor detection with NO backward mask — the Camilleri (2014)
    /// convention: 200 ms flash, σ = λ, 1-up/3-down staircase.
    static let flashMs = 200
    static let interIntervalGapMs = 500
    // Reserved for a future "processing-speed" advanced mode that re-adds the
    // backward mask (the gaborMask shader / GaborMaskView still exist):
    static let maskISIMs = 180
    static let maskMs = 120

    /// Spatial frequencies (cycles/deg) rotated one-per-session.
    static let trainingSFs: [Double] = [1.5, 3.0, 6.0]
    private static let sfRotationKey = "gaborSFRotation"

    let totalTrials: Int
    let staircase = AdaptiveStaircase()

    private var sessionStart: Date?
    private var feedbackTimer: Timer?
    private var trialTask: Task<Void, Never>?

    init(totalTrials: Int = 50) {
        self.totalTrials = totalTrials
        if UserDefaults.standard.bool(forKey: "gaborDisclaimerAccepted") {
            phase = .ready
        }
    }

    // MARK: - Disclaimer

    func acceptDisclaimer() {
        UserDefaults.standard.set(true, forKey: "gaborDisclaimerAccepted")
        phase = .ready
    }

    func showDisclaimer() {
        phase = .disclaimer
    }

    // MARK: - Session lifecycle

    func showInstructions() {
        phase = .instructions
    }

    func startExercise() {
        currentTrial = 0
        score = 0
        sessionStart = Date()

        // Pick this session's spatial frequency, then advance the rotation.
        let idx = UserDefaults.standard.integer(forKey: Self.sfRotationKey)
        sessionSF = Self.trainingSFs[idx % Self.trainingSFs.count]
        UserDefaults.standard.set(idx + 1, forKey: Self.sfRotationKey)

        // Carry difficulty forward: start ~3x above the last threshold measured
        // for this exercise + SF, so the staircase doesn't re-descend from
        // scratch every session. First session starts at 0.4 (clearly visible
        // but not trivially bold) with a large initial staircase step, so it
        // reaches genuine near-threshold difficulty within a few trials rather
        // than a long easy warm-up.
        let lastT = GaborSessionStore.shared.lastThreshold(forExercise: exerciseType.rawValue, sf: sessionSF)
        let start = lastT.map { min(0.4, $0 * 3.0) } ?? 0.4
        staircase.reset(startContrast: start)

        generateTrial()
    }

    func generateTrial() {
        trialTask?.cancel()
        currentTrial += 1
        targetInterval = Int.random(in: 1...2)
        trialOrientation = Double.random(in: 0..<(.pi))
        // Reset the stage synchronously before entering .presenting, so a render
        // can't briefly show the previous trial's .response controls before the
        // async sequence sets .fixation.
        stage = .fixation
        phase = .presenting
        runTrialSequence()
    }

    /// Runs the timed flash sequence on the main actor, checking for
    /// cancellation between each step so a new trial / return-to-picker can
    /// interrupt it cleanly.
    private func runTrialSequence() {
        trialTask = Task { @MainActor [weak self] in
            self?.stage = .fixation
            try? await Task.sleep(for: .milliseconds(Self.fixationMs))
            if Task.isCancelled { return }

            self?.stage = .interval(1)
            try? await Task.sleep(for: .milliseconds(Self.flashMs))
            if Task.isCancelled { return }

            self?.stage = .gap
            try? await Task.sleep(for: .milliseconds(Self.interIntervalGapMs))
            if Task.isCancelled { return }

            self?.stage = .interval(2)
            try? await Task.sleep(for: .milliseconds(Self.flashMs))
            if Task.isCancelled { return }

            self?.stage = .response
        }
    }

    /// Submit the user's choice of which flash held the pattern (1 or 2). Only
    /// valid once the sequence has reached `.response`.
    func submitResponse(_ interval: Int) {
        guard case .presenting = phase, case .response = stage else { return }

        let correct = interval == targetInterval
        if correct { score += 1 }
        staircase.recordResponse(correct: correct)
        phase = .feedback(correct: correct)

        feedbackTimer?.invalidate()
        feedbackTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
            self?.advanceAfterFeedback()
        }
    }

    private func advanceAfterFeedback() {
        if currentTrial >= totalTrials {
            completeSession()
        } else {
            generateTrial()
        }
    }

    private func completeSession() {
        phase = .complete
        saveSession()
    }

    func saveSession() {
        let duration = sessionStart.map { Date().timeIntervalSince($0) } ?? 0
        let record = GaborSessionRecord(
            date: Date(),
            exerciseType: exerciseType.rawValue,
            trialCount: currentTrial,
            correctCount: score,
            contrastThreshold: staircase.threshold(),
            durationSeconds: duration,
            spatialFrequency: sessionSF
        )
        GaborSessionStore.shared.save(record)
    }

    /// Save partial results and reset for a clean state.
    func cancelSession() {
        trialTask?.cancel()
        feedbackTimer?.invalidate()
        if currentTrial > 0 {
            saveSession()
        }
    }

    /// Abandon the current attempt (without saving) and return to the picker.
    /// Cancels the running flash sequence and any pending feedback timer so
    /// neither can advance the trial after we've left, and zeroes the counters
    /// so a later window-close won't persist the abandoned attempt.
    func returnToPicker() {
        trialTask?.cancel()
        feedbackTimer?.invalidate()
        currentTrial = 0
        score = 0
        stage = .fixation
        phase = .ready
    }

    var accuracyPercent: Int {
        guard currentTrial > 0 else { return 0 }
        return Int(round(Double(score) / Double(currentTrial) * 100))
    }

    var thresholdDisplay: String {
        if let t = staircase.threshold() {
            String(format: "%.1f%%", t * 100)
        } else {
            "—"
        }
    }

    /// Whether the given flash interval (1 or 2) holds the target this trial.
    /// Exactly one interval does; the other is a plain gray disc. Centralized
    /// here (rather than inline in the view) so the "only one flash has the
    /// pattern" invariant is unit-testable.
    func isTargetInterval(_ interval: Int) -> Bool {
        interval == targetInterval
    }

    /// Session spatial frequency for display, e.g. "1.5 cpd", "3 cpd".
    var sessionSFDisplay: String {
        sessionSF == sessionSF.rounded()
            ? "\(Int(sessionSF)) cpd"
            : "\(sessionSF) cpd"
    }
}
