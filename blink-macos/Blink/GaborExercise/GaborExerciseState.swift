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
            """
            Two brief flashes appear one after another. Only one of them contains a \
            faint striped pattern (a Gabor patch) — the other flash is a plain gray \
            disc. A textured mask follows each flash. Your job: pick which flash — \
            the first or the second — held the striped pattern.

            As you answer correctly the pattern grows fainter, and it becomes bolder \
            when you miss, so the task keeps pace with you.
            """
        case .flanker:
            """
            Same idea as Spot the Flash: two brief flashes appear one after another, \
            only one holds a faint striped pattern in the center, and a mask follows \
            each flash. The twist — two bold striped patches bracket the center of \
            both flashes, making the faint target harder to pick out.

            Pick which flash — the first or the second — held the center pattern, \
            ignoring the bold patches on either side.
            """
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
    static let flashMs = 120
    static let maskMs = 120
    static let gapMs = 500

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
        staircase.reset()
        sessionStart = Date()

        // Pick this session's spatial frequency, then advance the rotation.
        let idx = UserDefaults.standard.integer(forKey: Self.sfRotationKey)
        sessionSF = Self.trainingSFs[idx % Self.trainingSFs.count]
        UserDefaults.standard.set(idx + 1, forKey: Self.sfRotationKey)

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

            self?.stage = .mask(1)
            try? await Task.sleep(for: .milliseconds(Self.maskMs))
            if Task.isCancelled { return }

            self?.stage = .gap
            try? await Task.sleep(for: .milliseconds(Self.gapMs))
            if Task.isCancelled { return }

            self?.stage = .interval(2)
            try? await Task.sleep(for: .milliseconds(Self.flashMs))
            if Task.isCancelled { return }

            self?.stage = .mask(2)
            try? await Task.sleep(for: .milliseconds(Self.maskMs))
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
            durationSeconds: duration
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

    /// Session spatial frequency for display, e.g. "1.5 cpd", "3 cpd".
    var sessionSFDisplay: String {
        sessionSF == sessionSF.rounded()
            ? "\(Int(sessionSF)) cpd"
            : "\(sessionSF) cpd"
    }
}
