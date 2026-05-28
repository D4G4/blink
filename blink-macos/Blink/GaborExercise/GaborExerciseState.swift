import Foundation
import SwiftUI

enum ExerciseType: String, CaseIterable, Identifiable {
    case contrastDetection = "Contrast Detection"
    case orientationDiscrimination = "Orientation"
    case flankerMasking = "Flanker Masking"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .contrastDetection: "circle.lefthalf.filled"
        case .orientationDiscrimination: "arrow.up.left.and.arrow.down.right"
        case .flankerMasking: "circle.grid.3x3"
        }
    }

    var headline: String {
        switch self {
        case .contrastDetection:
            "Spot the Hidden Pattern"
        case .orientationDiscrimination:
            "Read the Tilt"
        case .flankerMasking:
            "Focus Through Distractions"
        }
    }

    var explanation: String {
        switch self {
        case .contrastDetection:
            """
            Two circles appear on a gray background — one contains a faint striped \
            pattern (a Gabor patch), the other is plain gray. Your job is to click \
            the circle that contains the pattern.

            As you get better, the pattern becomes fainter, training your brain to \
            detect subtler contrasts. This is the most studied form of contrast \
            sensitivity training and the foundation of visual perceptual learning.
            """
        case .orientationDiscrimination:
            """
            A single striped pattern appears in the center of the screen, tilted \
            slightly to the left or to the right. Click the direction it's tilting.

            The pattern gets fainter as you improve, training your visual cortex to \
            extract orientation information from weaker signals. This strengthens \
            the same neural pathways used when reading small text or distinguishing \
            fine details.
            """
        case .flankerMasking:
            """
            Three striped patterns appear in a row. The two outer patterns (flankers) \
            are bold and vertical. The center pattern is faint and tilted slightly \
            left or right. Your task: identify which way the center pattern tilts, \
            while ignoring the flankers.

            This is the hardest exercise. The flankers create lateral masking — they \
            interfere with your ability to see the center target. Training with \
            flankers improves your brain's ability to focus on relevant details \
            while filtering out visual noise. This is especially helpful for \
            crowded scenes like reading dense text.
            """
        }
    }

    var howToPlay: String {
        switch self {
        case .contrastDetection:
            "Click the circle that contains the pattern — left or right."
        case .orientationDiscrimination:
            "Click \"Tilted Left\" or \"Tilted Right\" to match the pattern's tilt."
        case .flankerMasking:
            "Ignore the outer patterns. Click the tilt direction of the center pattern."
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

/// Drives a Gabor exercise session — manages trials, scoring, and the adaptive staircase.
final class GaborExerciseState: ObservableObject {
    @Published var exerciseType: ExerciseType = .contrastDetection
    @Published var phase: ExercisePhase = .disclaimer
    @Published var currentTrial: Int = 0
    @Published var score: Int = 0

    // Trial-specific state
    @Published var targetPosition: Int = 0         // 0 = left, 1 = right (contrast detection)
    @Published var targetOrientation: Double = 0    // radians (orientation / flanker)
    @Published var flankerDistanceLevel: Int = 1      // 0/1/2 → close/medium/far (resolved by view via config)

    let totalTrials: Int
    let staircase = AdaptiveStaircase()

    private var sessionStart: Date?
    private var feedbackTimer: Timer?

    init(totalTrials: Int = 25) {
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
        generateTrial()
    }

    func generateTrial() {
        currentTrial += 1

        switch exerciseType {
        case .contrastDetection:
            targetPosition = Int.random(in: 0...1)

        case .orientationDiscrimination:
            // +15° or -15° from vertical
            let tiltDegrees: Double = Bool.random() ? 15 : -15
            targetOrientation = tiltDegrees * .pi / 180.0

        case .flankerMasking:
            let tiltDegrees: Double = Bool.random() ? 15 : -15
            targetOrientation = tiltDegrees * .pi / 180.0
            flankerDistanceLevel = Int.random(in: 0...2)
        }

        phase = .presenting
    }

    /// Submit user's response. For contrast detection: 0 = left, 1 = right.
    /// For orientation/flanker: 0 = tilted left, 1 = tilted right.
    func submitResponse(_ response: Int) {
        guard case .presenting = phase else { return }

        let correct: Bool
        switch exerciseType {
        case .contrastDetection:
            correct = response == targetPosition
        case .orientationDiscrimination, .flankerMasking:
            // Renderer convention (verified empirically 2026-05-27 by
            // rendering +30° and -30° patches via the actual
            // GaborRenderer math and inspecting the output):
            //   positive `orientation` → stripes go top-LEFT to
            //     bottom-RIGHT ("\") → that's TILTED LEFT visually
            //   negative `orientation` → stripes go top-RIGHT to
            //     bottom-LEFT ("/") → that's TILTED RIGHT visually
            // The CGBitmapContext data buffer is laid out with
            // Cartesian y-up (bottom row first), not the screen y-down
            // I initially derived — that's where the inversion comes
            // from. Response 0 = "Tilted Left", response 1 = "Tilted
            // Right" (from button order in GaborExerciseView).
            let expectedResponse = targetOrientation > 0 ? 0 : 1
            correct = response == expectedResponse
        }

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
        feedbackTimer?.invalidate()
        if currentTrial > 0 {
            saveSession()
        }
    }

    /// Abandon the current attempt (without saving) and return to the picker.
    /// Invalidates any pending feedback timer so it can't advance the trial
    /// after we've left, and zeroes the counters so a later window-close
    /// won't persist the abandoned attempt.
    func returnToPicker() {
        feedbackTimer?.invalidate()
        currentTrial = 0
        score = 0
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
}
