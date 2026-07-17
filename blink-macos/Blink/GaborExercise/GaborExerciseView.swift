import SwiftUI

struct GaborExerciseView: View {
    @ObservedObject var state: GaborExerciseState
    let theme: BlinkTheme
    let onDismiss: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    /// The Gabor stimulus is only on screen during a trial; only then do we
    /// switch to the mid-gray field a patch must sit on. The picker,
    /// instructions, and results keep the app's dark look.
    private var onGray: Bool {
        switch state.phase {
        case .presenting, .feedback: return true
        default: return false
        }
    }

    var body: some View {
        ZStack {
            (onGray ? Color(white: 0.5) : Color.black).ignoresSafeArea(.all)

            VStack(spacing: 0) {
                switch state.phase {
                case .disclaimer:
                    DisclaimerCard(onAccept: { state.acceptDisclaimer() })
                case .ready:
                    ReadyPhase(state: state, theme: theme, colorScheme: colorScheme)
                case .instructions:
                    InstructionsPhase(state: state, theme: theme, colorScheme: colorScheme)
                case .presenting:
                    TrialPhase(state: state, theme: theme)
                case .feedback(let correct):
                    TrialPhase(state: state, theme: theme, feedbackCorrect: correct)
                case .complete:
                    CompletePhase(state: state, theme: theme, colorScheme: colorScheme, onDismiss: onDismiss)
                }

                ExerciseFooter(onGray: onGray, onShowDisclaimer: { state.showDisclaimer() })
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

}

// MARK: - Disclaimer

private struct DisclaimerCard: View {
    let onAccept: () -> Void

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            Image(systemName: "eye.trianglebadge.exclamationmark")
                .font(.system(size: 48))
                .foregroundStyle(.white)

            Text("Before You Start")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(.white)

            Text("""
                This exercise is for general wellness and entertainment purposes only. \
                It is not a medical device, does not diagnose or treat any condition, \
                and is not a substitute for professional eye care.

                Consult an eye care professional before starting any vision training \
                program. Results may vary. If you experience discomfort, stop immediately.
                """)
                .font(.system(size: 16))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 540)
                .lineSpacing(5)

            Button("I Understand") {
                onAccept()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Spacer()
        }
        .padding(40)
    }
}

// MARK: - Ready Phase (exercise picker)

private struct ReadyPhase: View {
    @ObservedObject var state: GaborExerciseState
    let theme: BlinkTheme
    let colorScheme: ColorScheme

    private var fg: Color { .white }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            Text("Eye Exercise")
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(fg)
                .padding(.bottom, 8)

            Text("A brief focus-and-attention game with faint striped patterns")
                .font(.system(size: 15))
                .foregroundStyle(fg)
                .padding(.bottom, 40)

            // Exercise type cards
            HStack(spacing: 20) {
                ForEach(ExerciseType.allCases) { type in
                    ExerciseTypeCard(
                        type: type,
                        isSelected: state.exerciseType == type,
                        theme: theme,
                        colorScheme: colorScheme
                    ) {
                        state.exerciseType = type
                    }
                }
            }
            .frame(maxWidth: 560)

            Spacer()
                .frame(height: 40)

            Button {
                state.showInstructions()
            } label: {
                Text("Continue")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(theme.textOnAccent(for: colorScheme))
                    .frame(width: 180, height: 44)
                    .background(theme.accent(for: colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .padding(40)
    }
}

private struct ExerciseTypeCard: View {
    let type: ExerciseType
    let isSelected: Bool
    let theme: BlinkTheme
    let colorScheme: ColorScheme
    let onTap: () -> Void

    private var fg: Color { .white }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 14) {
                Image(systemName: type.icon)
                    .font(.system(size: 28))
                    .foregroundStyle(isSelected ? theme.accent : fg)
                    .frame(height: 36)

                Text(type.rawValue)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(fg)

                Text(type.headline)
                    .font(.system(size: 12))
                    .foregroundStyle(fg)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 140)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(fg.opacity(isSelected ? 0.2 : 0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? theme.accent : .clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Instructions Phase

private struct InstructionsPhase: View {
    @ObservedObject var state: GaborExerciseState
    let theme: BlinkTheme
    let colorScheme: ColorScheme

    private var fg: Color { .white }
    private let config = GaborDisplayConfig.current()

    // Illustrative demo-patch parameters (fixed at 3 cpd — not the session SF).
    private let demoSize: CGFloat = 96
    private var demoCPP: Double { config.cyclesPerPoint(forCPD: 3) }
    private var demoSigma: Double { config.sigmaPoints(forCPD: 3) }
    private var demoCollinearSigma: Double { 1.0 / demoCPP }
    private var demoCollinearSep: Double { 3.0 / demoCPP }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                Image(systemName: state.exerciseType.icon)
                    .font(.system(size: 52))
                    .foregroundStyle(theme.accent)
                    .padding(.top, 24)
                    .padding(.bottom, 20)

                Text(state.exerciseType.rawValue)
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(fg)
                    .padding(.bottom, 6)

                Text(state.exerciseType.headline)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(fg)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 36)

                // Explanation card
                VStack(alignment: .leading, spacing: 22) {
                    demoSection
                    Divider().background(fg.opacity(0.15))
                    instructionSection("How to play", "hand.tap", state.exerciseType.howToPlay)
                    Divider().background(fg.opacity(0.15))
                    instructionSection("How this helps", "brain.head.profile", state.exerciseType.benefit)
                }
                .padding(28)
                .frame(maxWidth: 560)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(fg.opacity(0.1))
                )

                HStack(spacing: 16) {
                    Button {
                        state.phase = .ready
                    } label: {
                        Text("Back")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(fg)
                            .frame(width: 100, height: 40)
                            .background(fg.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)

                    Button {
                        state.startExercise()
                    } label: {
                        Text("Start \(state.totalTrials) Trials")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(theme.textOnAccent(for: colorScheme))
                            .frame(width: 180, height: 44)
                            .background(theme.accent(for: colorScheme))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 36)
                .padding(.bottom, 24)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 40)
        }
    }

    /// One titled section of the instructions card. `.fixedSize(vertical)` lets
    /// the body text wrap to its full height instead of truncating to one line
    /// when the column is height-constrained.
    private func instructionSection(_ title: String, _ icon: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(fg)
            Text(text)
                .font(.system(size: 14))
                .foregroundStyle(fg)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// A labelled two-panel example of one trial — one flash holds the pattern,
    /// the other is plain gray — so you know what to look for before the real
    /// (fainter, briefer) stimulus.
    private var demoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("What you'll see", systemImage: "eye")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(fg)

            HStack(spacing: 28) {
                demoFlash(label: "First flash", hasTarget: true)
                demoFlash(label: "Second flash", hasTarget: false)
            }
            .frame(maxWidth: .infinity)

            Text(demoCaption)
                .font(.system(size: 13))
                .foregroundStyle(fg.opacity(0.85))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var demoCaption: String {
        switch state.exerciseType {
        case .detection:
            "Only one flash holds a striped pattern — here, the first, so you'd choose First. In the real exercise it's much fainter and appears only briefly."
        case .flanker:
            "Both flashes show the two bold patches; only one also hides a faint pattern in the center — here, the first. In the real exercise the center is much fainter."
        }
    }

    private func demoFlash(label: String, hasTarget: Bool) -> some View {
        VStack(spacing: 8) {
            Group {
                if state.exerciseType == .flanker {
                    CollinearGaborView(
                        size: demoSize,
                        targetContrast: hasTarget ? 0.9 : 0,
                        flankerContrast: 0.9,
                        spatialFrequencyCyclesPerPoint: demoCPP,
                        orientation: 0,
                        sigmaPoints: demoCollinearSigma,
                        separationPoints: demoCollinearSep
                    )
                } else {
                    GaborPatchView(
                        size: demoSize,
                        contrast: hasTarget ? 0.9 : 0,
                        spatialFrequencyCyclesPerPoint: demoCPP,
                        orientation: 0,
                        sigmaPoints: demoSigma
                    )
                }
            }
            .frame(width: demoSize, height: demoSize)
            .clipShape(Circle())
            .overlay(Circle().stroke(fg.opacity(0.2), lineWidth: 1))

            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(fg)
        }
    }
}

// MARK: - Trial Phase

private struct TrialPhase: View {
    @ObservedObject var state: GaborExerciseState
    let theme: BlinkTheme
    var feedbackCorrect: Bool?

    private let fg: Color = Color(white: 0.12)
    private let config = GaborDisplayConfig.current()

    // Per-session render parameters derived from the session's spatial frequency.
    private var patchSize: CGFloat { config.patchPointSize }
    private var cyclesPerPoint: Double { config.cyclesPerPoint(forCPD: state.sessionSF) }
    private var sigma: Double { config.sigmaPoints(forCPD: state.sessionSF) }

    /// High-contrast flankers / mask.
    private let boldContrast: Double = 0.9

    var body: some View {
        VStack(spacing: 24) {
            // Header
            HStack {
                Text("Trial \(state.currentTrial) of \(state.totalTrials)")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(fg)
                Spacer()
                Text("Score: \(state.score)/\(state.currentTrial)")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(fg)
            }
            .padding(.horizontal, 60)
            .padding(.top, 20)

            ProgressDots(current: state.currentTrial, total: state.totalTrials, theme: theme, trialResults: state.staircase.trialResults)
                .padding(.horizontal, 60)

            Spacer()

            // Stimulus sits on the mid-gray field (matched to the patch's mean
            // luminance), so its Gaussian-tapered edges blend in with no
            // visible disc or aperture.
            ZStack {
                stimulusForStage
                    .opacity(feedbackCorrect != nil ? 0.4 : 1.0)

                if let correct = feedbackCorrect {
                    FeedbackOverlay(correct: correct)
                }
            }

            Spacer()

            responseArea

            Spacer()
                .frame(height: 24)
        }
    }

    // MARK: Stimulus (switches on the trial stage)

    @ViewBuilder
    private var stimulusForStage: some View {
        switch state.stage {
        case .fixation, .gap, .response:
            FixationCross()
        case .interval(let i):
            intervalStimulus(i)
        case .mask:
            GaborMaskView(
                size: patchSize,
                contrast: boldContrast,
                spatialFrequencyCyclesPerPoint: cyclesPerPoint,
                sigmaPoints: sigma
            )
            .clipShape(Circle())
        }
    }

    /// One interval's flash: for detection, the target patch (or a plain gray
    /// disc); for the flanker exercise, the target flanked by two bold
    /// collinear Gabors — composited in a single shader pass so the envelopes
    /// overlap at the classic ~3λ spacing without occluding. A subtle "1"/"2"
    /// marker sits below.
    @ViewBuilder
    private func intervalStimulus(_ i: Int) -> some View {
        ZStack {
            if state.exerciseType == .flanker {
                CollinearGaborView(
                    size: patchSize,
                    targetContrast: state.isTargetInterval(i) ? state.staircase.currentContrast : 0,
                    flankerContrast: boldContrast,
                    spatialFrequencyCyclesPerPoint: cyclesPerPoint,
                    orientation: state.trialOrientation,
                    sigmaPoints: collinearSigma,
                    separationPoints: collinearSeparation
                )
                .clipShape(Circle())
            } else {
                centerPatch(showTarget: state.isTargetInterval(i))
            }
            intervalLabel(i)
        }
    }

    private func centerPatch(showTarget: Bool) -> some View {
        GaborPatchView(
            size: patchSize,
            contrast: showTarget ? state.staircase.currentContrast : 0,
            spatialFrequencyCyclesPerPoint: cyclesPerPoint,
            orientation: showTarget ? state.trialOrientation : 0,
            sigmaPoints: sigma
        )
        .clipShape(Circle())
    }

    // Collinear flanker geometry uses the classic Polat convention: σ = one
    // wavelength (tighter than the detection patch's 2λ) so flankers set 3λ
    // from the target are distinct but still interact laterally. Both are
    // derived from the session SF (1 / cyclesPerPoint = λ in points).
    private var collinearSigma: Double { 1.0 / cyclesPerPoint }        // σ = λ
    private var collinearSeparation: Double { 3.0 / cyclesPerPoint }   // 3λ

    private func intervalLabel(_ i: Int) -> some View {
        Text("\(i)")
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(fg.opacity(0.55))
            .offset(y: patchSize * 0.5 + 20)
    }

    // MARK: Response

    @ViewBuilder
    private var responseArea: some View {
        if case .response = state.stage, feedbackCorrect == nil {
            VStack(spacing: 10) {
                Text("Which flash had the pattern?")
                    .font(.system(size: 13))
                    .foregroundStyle(fg)

                HStack(spacing: 28) {
                    ResponseButton(label: "First", icon: "1.circle", theme: theme, colorScheme: .dark) {
                        state.submitResponse(1)
                    }
                    .keyboardShortcut(.leftArrow, modifiers: [])
                    ResponseButton(label: "Second", icon: "2.circle", theme: theme, colorScheme: .dark) {
                        state.submitResponse(2)
                    }
                    .keyboardShortcut(.rightArrow, modifiers: [])
                }

                Text("or press ← / →")
                    .font(.system(size: 11))
                    .foregroundStyle(fg.opacity(0.7))
            }
            .padding(.horizontal, 60)
        } else {
            // Reserve the space so the stimulus doesn't jump when the
            // response prompt appears.
            Color.clear.frame(height: 90)
        }
    }
}

// MARK: - Complete Phase

private struct CompletePhase: View {
    @ObservedObject var state: GaborExerciseState
    let theme: BlinkTheme
    let colorScheme: ColorScheme
    let onDismiss: () -> Void

    private var fg: Color { .white }

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 52))
                .foregroundStyle(theme.accent)

            Text("Session Complete")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(fg)

            VStack(spacing: 14) {
                StatRow(label: "Exercise", value: state.exerciseType.rawValue, fg: fg)
                StatRow(label: "Accuracy", value: "\(state.accuracyPercent)%", fg: fg)
                StatRow(label: "Score", value: "\(state.score)/\(state.totalTrials)", fg: fg)
                StatRow(label: "Contrast threshold", value: state.thresholdDisplay, fg: fg)
                StatRow(label: "Spatial frequency", value: state.sessionSFDisplay, fg: fg)
            }
            .padding(24)
            .frame(maxWidth: 340)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(fg.opacity(0.1))
            )

            GaborProgressSparkline(
                history: GaborSessionStore.shared.thresholdHistory(forExercise: state.exerciseType.rawValue),
                tint: fg
            )
            .frame(maxWidth: 340)

            HStack(spacing: 16) {
                Button {
                    state.phase = .ready
                } label: {
                    Text("Try Again")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(fg)
                        .frame(width: 120, height: 40)
                        .background(fg.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)

                Button {
                    onDismiss()
                } label: {
                    Text("Done")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(theme.textOnAccent(for: colorScheme))
                        .frame(width: 120, height: 44)
                        .background(theme.accent(for: colorScheme))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }

            Spacer()
        }
        .padding(40)
    }
}

private struct StatRow: View {
    let label: String
    let value: String
    let fg: Color

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(fg)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(fg)
        }
    }
}

// MARK: - Shared Components

private struct ResponseButton: View {
    let label: String
    let icon: String
    let theme: BlinkTheme
    let colorScheme: ColorScheme
    let action: () -> Void

    private var fg: Color { Color(white: 0.12) }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                Text(label)
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundStyle(fg)
            .frame(width: 160, height: 44)
            .background(fg.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(fg.opacity(0.15), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct ProgressDots: View {
    let current: Int
    let total: Int
    let theme: BlinkTheme
    let trialResults: [(contrast: Double, correct: Bool)]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<min(total, 30), id: \.self) { index in
                Circle()
                    .fill(dotColor(for: index))
                    .frame(width: dotSize, height: dotSize)
            }
            if total > 30 {
                Text("+\(total - 30)")
                    .font(.system(size: 9))
                    .foregroundStyle(.white)
            }
        }
    }

    private func dotColor(for index: Int) -> Color {
        guard index < trialResults.count else {
            return .black
        }
        return trialResults[index].correct ? .green : .red
    }

    private var dotSize: CGFloat { total > 25 ? 5 : 7 }
}

private struct FeedbackOverlay: View {
    let correct: Bool

    var body: some View {
        Image(systemName: correct ? "checkmark.circle.fill" : "xmark.circle.fill")
            .font(.system(size: 56))
            .foregroundStyle(correct ? .green : .red)
            .transition(.scale.combined(with: .opacity))
    }
}

private struct ExerciseFooter: View {
    let onGray: Bool
    let onShowDisclaimer: () -> Void

    var body: some View {
        let footerColor: Color = onGray ? Color(white: 0.12) : .white
        HStack {
            Text("For wellness purposes only \u{2014} not medical advice")
                .font(.system(size: 10))
                .foregroundStyle(footerColor)

            Spacer()

            Button("Disclaimer") {
                onShowDisclaimer()
            }
            .buttonStyle(.plain)
            .font(.system(size: 10))
            .foregroundStyle(footerColor)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }
}
