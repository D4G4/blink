import Foundation
import SwiftUI
import AppKit

enum ExerciseType: String, CaseIterable, Identifiable {
    /// Primary: single-Gabor temporal two-interval detection.
    case detection = "Spot the Flash"
    /// Advanced: same task with two bold collinear flankers bracketing the target.
    case flanker = "Flanker Focus"
    /// Contour integration: find a closed loop of aligned Gabors hidden in noise.
    case contour = "Trace the Shape"

    var id: String { rawValue }

    /// Contour is a single-presentation GROUPING task (not the temporal two-
    /// interval detection flow the other two share).
    var isContour: Bool { self == .contour }

    var icon: String {
        switch self {
        case .detection: "sparkle.magnifyingglass"
        case .flanker: "circle.grid.3x3"
        case .contour: "circle.dashed"
        }
    }

    var headline: String {
        switch self {
        case .detection:
            "Which flash held the pattern?"
        case .flanker:
            "Focus through bold distractions"
        case .contour:
            "Which way does the hidden loop point?"
        }
    }

    /// One-line "what it trains", short enough for a picker card so you can
    /// choose by benefit. Honest wellness framing (see `benefit`).
    var shortBenefit: String {
        switch self {
        case .detection: "Trains faint-detail (contrast) vision"
        case .flanker:   "Trains seeing past nearby clutter"
        case .contour:   "Trains grouping shapes out of noise"
        }
    }

    var explanation: String {
        switch self {
        case .detection:
            "Two brief flashes, one after the other. Only one holds a faint striped pattern; the other is plain gray. Spot which flash had it."
        case .flanker:
            "Like Spot the Flash, but two bold striped patches bracket the center of both flashes. Only one flash also hides a faint pattern between them."
        case .contour:
            "A screen fills with tiny striped patches pointing every which way. Hidden among them, about sixteen line up into a closed loop shaped like an egg with one pointed end."
        }
    }

    var howToPlay: String {
        switch self {
        case .detection:
            "Watch both flashes, then choose First or Second — whichever held the pattern."
        case .flanker:
            "Ignore the two bold patches. Choose First or Second — whichever flash held the faint center pattern."
        case .contour:
            "Look for the patches that line up into a smooth closed outline — a dotted egg with one pointed end — while the rest point at random. Choose Left or Right for the way the point faces. It's clear at first and hides more each round; if you truly can't find it, just guess."
        }
    }

    /// Honest, plain-English "how this helps" — describes the visual skill the
    /// task exercises, framed as a wellness activity. Never a medical/vision-
    /// improvement claim (see the disclaimer).
    var benefit: String {
        switch self {
        case .detection:
            "Trains contrast sensitivity — spotting faint, low-contrast detail, the vision you lean on for dim text, fog, night driving, or a dark screen. A wellness activity done little-and-often, not a medical treatment; results vary."
        case .flanker:
            "Trains seeing a target clearly when it's hemmed in by nearby clutter (lateral masking) — the skill behind reading crowded text or picking one thing out of a busy scene. A wellness activity, not a medical treatment; benefits build slowly."
        case .contour:
            "Trains visual grouping — your brain's knack for linking scattered edges into one whole shape (the 'good continuation' you use to follow a line on a graph or pick an object out of clutter). The patches are bold, not faint, so this isn't about faint-detail vision. A wellness activity, not a medical treatment; benefits build slowly and vary."
        }
    }
}

enum ExercisePhase {
    case disclaimer
    case ready
    case instructions
    case science
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
    /// Contour exercise: the full noise+contour field is displayed.
    case field
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

    // Contour exercise per-trial state (single-presentation grouping task).
    /// Which way the hidden loop's pinched end faces — the answer.
    @Published var contourFacing: ContourFacing = .right
    /// Orientation jitter Δβ (radians) applied to the contour this trial.
    @Published var contourJitterRad: Double = 0
    /// Per-trial RNG seed, so the field is stable within a trial.
    @Published var contourSeed: UInt64 = 1
    /// Δβ staircase for the contour exercise.
    let contourStaircase = ContourStaircase()

    // MARK: - Timing constants (milliseconds)

    static let fixationMs = 500
    /// Single-Gabor detection with NO backward mask — the Camilleri (2014)
    /// unmasked convention: 200 ms flash, σ = λ, 1-up/3-down staircase. A masked
    /// "processing-speed" mode (40 ms target + plaid mask at a staircased SOA)
    /// is a distinct future mode; the `gaborMask` shader / `GaborMaskView` /
    /// `.mask` stage are parked for it but are NOT wired into the trial sequence.
    static let flashMs = 200
    static let interIntervalGapMs = 500
    /// Contour: how long the field shows before the Left/Right buttons appear
    /// (the field stays visible during the response — a gentle wellness variant
    /// of the ~1 s single presentation).
    static let contourLookMs = 900

    /// Spatial frequencies (cycles/deg) rotated one-per-session.
    static let trainingSFs: [Double] = [1.5, 3.0, 6.0]
    private static let sfRotationKey = "gaborSFRotation"

    let totalTrials: Int
    // Large initial log step (0.35 ≈ ×2.2 per down-step) so the track descends
    // from the visible start to genuine near-threshold in ~5 down-steps; it
    // still halves at each reversal for fine convergence near threshold.
    let staircase = AdaptiveStaircase(initialLogStep: 0.35)

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

    func showScience() {
        phase = .science
    }

    func startExercise() {
        currentTrial = 0
        score = 0
        sessionStart = Date()

        if exerciseType.isContour {
            // Contour grouping task: start at Δβ = 0° (the loop is obvious) as a
            // warm-up, then the staircase raises the jitter into threshold.
            contourStaircase.reset(start: 0)
            generateTrial()
            return
        }

        // Pick this session's spatial frequency, then advance the rotation.
        let idx = UserDefaults.standard.integer(forKey: Self.sfRotationKey)
        sessionSF = Self.trainingSFs[idx % Self.trainingSFs.count]
        UserDefaults.standard.set(idx + 1, forKey: Self.sfRotationKey)

        // Carry difficulty forward: start ~3x above the last threshold measured
        // for this exercise + SF, so the staircase doesn't re-descend from
        // scratch every session. First session starts at 0.3 (clearly visible
        // but not bold); combined with the large initial log step the track
        // reaches genuine near-threshold difficulty within ~10 trials rather
        // than a long easy warm-up. Carryover is capped at 0.3 so a stale-high
        // stored threshold can't reintroduce the long warm-up.
        let lastT = GaborSessionStore.shared.lastThreshold(forExercise: exerciseType.rawValue, sf: sessionSF)
        let start = lastT.map { min(0.3, $0 * 3.0) } ?? 0.3
        staircase.reset(startContrast: start)

        generateTrial()
    }

    func generateTrial() {
        trialTask?.cancel()
        currentTrial += 1

        if exerciseType.isContour {
            contourFacing = Bool.random() ? .left : .right
            contourJitterRad = contourStaircase.jitterRad
            // Vary the field (distractor arrangement) each trial.
            contourSeed = UInt64(currentTrial) &* 0x9E3779B97F4A7C15 &+ 0x1234_5678
            stage = .field
            phase = .presenting
            runContourSequence()
            return
        }

        targetInterval = Int.random(in: 1...2)
        trialOrientation = Double.random(in: 0..<(.pi))
        // Reset the stage synchronously before entering .presenting, so a render
        // can't briefly show the previous trial's .response controls before the
        // async sequence sets .fixation.
        stage = .fixation
        phase = .presenting
        runTrialSequence()
    }

    /// Contour: show the field, then reveal the Left/Right buttons (field stays).
    private func runContourSequence() {
        trialTask = Task { @MainActor [weak self] in
            self?.stage = .field
            try? await Task.sleep(for: .milliseconds(Self.contourLookMs))
            if Task.isCancelled { return }
            self?.stage = .response
        }
    }

    /// Submit the contour answer — which way the loop's pinched end faces.
    func submitContourResponse(_ facing: ContourFacing) {
        guard exerciseType.isContour, case .presenting = phase, case .response = stage else { return }
        let correct = facing == contourFacing
        if correct { score += 1 }
        contourStaircase.record(correct: correct)
        phase = .feedback(correct: correct)
        feedbackTimer?.invalidate()
        feedbackTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
            self?.advanceAfterFeedback()
        }
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
            self?.playIntervalCue()
            try? await Task.sleep(for: .milliseconds(Self.flashMs))
            if Task.isCancelled { return }

            self?.stage = .gap
            try? await Task.sleep(for: .milliseconds(Self.interIntervalGapMs))
            if Task.isCancelled { return }

            self?.stage = .interval(2)
            self?.playIntervalCue()
            try? await Task.sleep(for: .milliseconds(Self.flashMs))
            if Task.isCancelled { return }

            self?.stage = .response
        }
    }

    /// Soft auditory interval marker — the PRIMARY cue for WHEN each flash
    /// occurs. The pattern-less interval is near-invisible on the mean-gray
    /// field (by design: a real Gabor has no outline), so conventional 2IFC
    /// detection marks intervals with a brief tone rather than a bright ring
    /// (Pelli & Bex 2013). The faint aperture ring is only a muted-system
    /// visual fallback. A fresh NSSound each call avoids one-shot clipped
    /// replay between the two closely-spaced intervals.
    private func playIntervalCue() {
        let cue = NSSound(named: "Tink")
        cue?.volume = 0.55
        cue?.play()
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
        // For contour the "threshold" is the Δβ jitter tolerance (degrees) and
        // there is no spatial frequency; it reuses the same record fields.
        let record = GaborSessionRecord(
            date: Date(),
            exerciseType: exerciseType.rawValue,
            trialCount: currentTrial,
            correctCount: score,
            contrastThreshold: exerciseType.isContour ? contourStaircase.threshold() : staircase.threshold(),
            durationSeconds: duration,
            spatialFrequency: exerciseType.isContour ? nil : sessionSF
        )
        GaborSessionStore.shared.save(record)
    }

    // MARK: - Complete-screen metrics (per exercise)

    /// Label for the primary threshold metric on the results screen.
    var primaryMetricLabel: String {
        exerciseType.isContour ? "Jitter tolerance" : "Contrast threshold"
    }

    /// Value for the primary threshold metric.
    var primaryMetricValue: String {
        if exerciseType.isContour {
            if let d = contourStaircase.threshold() { return String(format: "±%.0f°", d) }
            return "—"
        }
        return thresholdDisplay
    }

    /// Contour has no spatial-frequency row; the flash tasks do.
    var showsSpatialFrequency: Bool { !exerciseType.isContour }

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

    /// Session spatial-frequency LEVEL for display. Not labelled in cycles/deg:
    /// without a measured viewing distance and display size, cpd is not
    /// calibrated (see "The science"). The carrier is set as a fixed number of
    /// cycles across a screen-proportional patch, so what actually varies
    /// between sessions is the stripe fineness — reported here as a relative
    /// level rather than a false photometric number.
    var sessionSFDisplay: String {
        switch sessionSF {
        case ..<2.0: return "Low (coarse stripes)"
        case ..<4.5: return "Medium"
        default:     return "High (fine stripes)"
        }
    }
}
