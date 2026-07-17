import Foundation
import SwiftUI

enum ExerciseType: String, CaseIterable, Identifiable {
    /// Primary: single-Gabor temporal two-interval detection.
    case detection = "Spot the Flash"
    /// Contour integration: find a closed loop of aligned Gabors hidden in noise.
    case contour = "Trace the Shape"
    /// Peripheral crowding: read a tilted target sandwiched by flankers, off to
    /// the side, without looking at it.
    case crowding = "Sideways Focus"

    var id: String { rawValue }

    /// Contour is a single-presentation GROUPING task (not the temporal two-
    /// interval detection flow the other two share).
    var isContour: Bool { self == .contour }
    /// Crowding is a single-look peripheral IDENTIFICATION task.
    var isCrowding: Bool { self == .crowding }

    var icon: String {
        switch self {
        case .detection: "sparkle.magnifyingglass"
        case .contour: "circle.dashed"
        case .crowding: "dot.viewfinder"
        }
    }

    var headline: String {
        switch self {
        case .detection:
            "Which flash held the pattern?"
        case .contour:
            "Which way does the hidden loop point?"
        case .crowding:
            "Read the tilt out of the corner of your eye"
        }
    }

    /// One-line "what it trains", short enough for a picker card so you can
    /// choose by benefit. Honest wellness framing (see `benefit`).
    var shortBenefit: String {
        switch self {
        case .detection: "Trains faint-detail (contrast) vision"
        case .contour:   "Trains grouping shapes out of noise"
        case .crowding:  "Trains reading cluttered side vision"
        }
    }

    var explanation: String {
        switch self {
        case .detection:
            "Two brief flashes, one after the other. Only one holds a faint striped pattern; the other is plain gray. Spot which flash had it."
        case .contour:
            "A screen fills with tiny striped patches pointing every which way. Hidden among them, about sixteen line up into a closed loop shaped like an egg with one pointed end."
        case .crowding:
            "You stare at a center cross while a small striped patch flashes briefly off to one side, with two more patches hugging it. The trick is to read the middle one without looking straight at it."
        }
    }

    var howToPlay: String {
        switch self {
        case .detection:
            "Watch both flashes, then choose First or Second — whichever held the pattern."
        case .contour:
            "Look for the patches that line up into a smooth closed outline — a dotted egg with one pointed end — while the rest point at random. Choose Left or Right for the way the point faces. It's clear at first and hides more each round; if you truly can't find it, just guess."
        case .crowding:
            "Keep your eyes on the center cross the whole time — don't look at the patch. When it flashes to the side, judge whether the MIDDLE one leans left or right, then press ← or →. If you flick your eyes to it, it gets too easy and measures nothing."
        }
    }

    /// Honest, plain-English "how this helps" — describes the visual skill the
    /// task exercises, framed as a wellness activity. Never a medical/vision-
    /// improvement claim (see the disclaimer).
    var benefit: String {
        switch self {
        case .detection:
            "Trains contrast sensitivity — spotting faint, low-contrast detail, the vision you lean on for dim text, fog, night driving, or a dark screen. A wellness activity done little-and-often, not a medical treatment; results vary."
        case .contour:
            "Trains visual grouping — your brain's knack for linking scattered edges into one whole shape (the 'good continuation' you use to follow a line on a graph or pick an object out of clutter). The patches are bold, not faint, so this isn't about faint-detail vision. A wellness activity, not a medical treatment; benefits build slowly and vary."
        case .crowding:
            "Trains reading a target hemmed in by nearby clutter in side (peripheral) vision — the 'crowding' bottleneck that makes packed text or a busy shelf hard to parse away from where you look directly. A wellness activity for normally-sighted eyes, not a medical treatment; whether it carries over to everyday tasks isn't established, and results vary."
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

    // Crowding exercise per-trial state (single-look peripheral identification).
    /// Which side of fixation the target flashes on.
    @Published var crowdingSide: CrowdingSide = .right
    /// Target tilt sign: −1 leans left, +1 leans right (the answer).
    @Published var crowdingTiltSign: Int = 1
    /// Dimensionless target–flanker spacing ratio b (the staircased variable).
    @Published var crowdingB: Double = 0.8
    /// Independent random flanker orientations (radians).
    @Published var crowdingFlankerA: Double = 0
    @Published var crowdingFlankerB: Double = 0
    /// ~10% of trials show the target alone (acuity sanity floor) — not staircased.
    @Published var crowdingIsCatch: Bool = false
    /// b staircase (reuses the log 1-up/3-down; bounds are b, not contrast).
    let crowdingStaircase = AdaptiveStaircase(startContrast: 0.8, initialLogStep: 0.12,
                                              minContrast: 0.15, maxContrast: 1.0)

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

    // Crowding: a target flash then a backward mask, so the answer must be read
    // peripherally. Crowding is duration-INVARIANT (it's the flanker spacing,
    // not the speed, that drives difficulty), so the flash is only long enough
    // to be perceptible while still ending as a foveating saccade (~200 ms
    // latency) would land — the mask then curtails it. 120 ms (the strict
    // lab value) was too fast to see; 220 ms is a wellness-friendly compromise.
    static let crowdingFlashMs = 300
    static let crowdingMaskMs = 100
    /// Fraction of crowding trials with no flankers (acuity catch trials).
    static let crowdingCatchRate = 0.1

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

        if exerciseType.isCrowding {
            // Crowding: start at b = 0.8 (clearly uncrowded), staircase tightens.
            crowdingStaircase.reset(startContrast: 0.8)
            generateTrial()
            return
        }

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

        if exerciseType.isCrowding {
            crowdingSide = Bool.random() ? .left : .right
            crowdingTiltSign = Bool.random() ? 1 : -1
            crowdingIsCatch = Double.random(in: 0..<1) < Self.crowdingCatchRate
            crowdingB = crowdingStaircase.currentContrast
            crowdingFlankerA = Double.random(in: 0..<(.pi))
            crowdingFlankerB = Double.random(in: 0..<(.pi))
            stage = .fixation
            phase = .presenting
            runCrowdingSequence()
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

    /// Crowding: fixation → brief target flash → backward mask → response.
    private func runCrowdingSequence() {
        trialTask = Task { @MainActor [weak self] in
            self?.stage = .fixation
            try? await Task.sleep(for: .milliseconds(Self.fixationMs))
            if Task.isCancelled { return }
            self?.stage = .interval(1)                 // target flash
            try? await Task.sleep(for: .milliseconds(Self.crowdingFlashMs))
            if Task.isCancelled { return }
            self?.stage = .mask(1)                      // backward mask
            try? await Task.sleep(for: .milliseconds(Self.crowdingMaskMs))
            if Task.isCancelled { return }
            self?.stage = .response
        }
    }

    /// Submit the crowding answer — the target's tilt sign (−1 left, +1 right).
    /// Catch trials (no flankers) score but don't drive the b staircase.
    func submitTilt(_ sign: Int) {
        guard exerciseType.isCrowding, case .presenting = phase, case .response = stage else { return }
        let correct = sign == crowdingTiltSign
        if correct { score += 1 }
        if !crowdingIsCatch { crowdingStaircase.recordResponse(correct: correct) }
        phase = .feedback(correct: correct)
        feedbackTimer?.invalidate()
        feedbackTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
            self?.advanceAfterFeedback()
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
        // The "threshold" field is reused per exercise: contrast for detection,
        // Δβ degrees for contour, the Bouma ratio b for crowding. Only the flash
        // task has a spatial frequency.
        let threshold: Double?
        switch exerciseType {
        case .contour:  threshold = contourStaircase.threshold()
        case .crowding: threshold = crowdingStaircase.threshold()
        default:        threshold = staircase.threshold()
        }
        let record = GaborSessionRecord(
            date: Date(),
            exerciseType: exerciseType.rawValue,
            trialCount: currentTrial,
            correctCount: score,
            contrastThreshold: threshold,
            durationSeconds: duration,
            spatialFrequency: showsSpatialFrequency ? sessionSF : nil
        )
        GaborSessionStore.shared.save(record)
    }

    // MARK: - Complete-screen metrics (per exercise)

    /// Label for the primary threshold metric on the results screen.
    var primaryMetricLabel: String {
        switch exerciseType {
        case .contour:  return "Jitter tolerance"
        case .crowding: return "Crowding threshold"
        default:        return "Contrast threshold"
        }
    }

    /// Value for the primary threshold metric.
    var primaryMetricValue: String {
        switch exerciseType {
        case .contour:
            if let d = contourStaircase.threshold() { return String(format: "±%.0f°", d) }
            return "—"
        case .crowding:
            // Bouma ratio b = spacing ÷ eccentricity (dimensionless).
            if let b = crowdingStaircase.threshold() { return String(format: "b = %.2f", b) }
            return "—"
        default:
            return thresholdDisplay
        }
    }

    /// Only the flash tasks have a spatial-frequency row.
    var showsSpatialFrequency: Bool { !(exerciseType.isContour || exerciseType.isCrowding) }

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
