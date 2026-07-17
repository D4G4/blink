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
            (onGray ? Color(white: GaborDisplayConfig.meanLuminanceGray) : Color.black).ignoresSafeArea(.all)

            VStack(spacing: 0) {
                switch state.phase {
                case .disclaimer:
                    DisclaimerCard(onAccept: { state.acceptDisclaimer() })
                case .ready:
                    ReadyPhase(state: state, theme: theme, colorScheme: colorScheme)
                case .instructions:
                    InstructionsPhase(state: state, theme: theme, colorScheme: colorScheme)
                case .science:
                    SciencePhase(theme: theme, colorScheme: colorScheme, onBack: { state.showInstructions() })
                case .presenting:
                    if state.exerciseType.isContour {
                        ContourTrialView(state: state, theme: theme)
                    } else if state.exerciseType.isCrowding {
                        CrowdingTrialView(state: state, theme: theme)
                    } else {
                        TrialPhase(state: state, theme: theme)
                    }
                case .feedback(let correct):
                    if state.exerciseType.isContour {
                        ContourTrialView(state: state, theme: theme, feedbackCorrect: correct)
                    } else if state.exerciseType.isCrowding {
                        CrowdingTrialView(state: state, theme: theme, feedbackCorrect: correct)
                    } else {
                        TrialPhase(state: state, theme: theme, feedbackCorrect: correct)
                    }
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
        GeometryReader { geo in
            // Responsive card size: fills the width on a big screen (capped so
            // it doesn't get silly) and shrinks to fit a small one. Divides by
            // the actual card count so adding exercises never overflows.
            let n = CGFloat(ExerciseType.allCases.count)
            let cardW = min(max((geo.size.width - 80 - (n - 1) * 24) / n, 140), 300)
            VStack(spacing: 0) {
                Spacer(minLength: 0)

                Text("Eye Exercise")
                    .font(.system(size: 40, weight: .bold))
                    .foregroundStyle(fg)
                    .padding(.bottom, 10)

                Text("Brief Gabor-patch exercises — each trains a different visual skill")
                    .font(.system(size: 18))
                    .foregroundStyle(fg.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 48)

                // Exercise type cards
                HStack(spacing: 24) {
                    ForEach(ExerciseType.allCases) { type in
                        ExerciseTypeCard(
                            type: type,
                            isSelected: state.exerciseType == type,
                            theme: theme,
                            colorScheme: colorScheme,
                            width: cardW
                        ) {
                            state.exerciseType = type
                        }
                    }
                }

                Spacer().frame(height: 48)

                Button {
                    state.showInstructions()
                } label: {
                    Text("Continue")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(theme.textOnAccent(for: colorScheme))
                        .frame(width: 210, height: 50)
                        .background(theme.accent(for: colorScheme))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(40)
        }
    }
}

private struct ExerciseTypeCard: View {
    let type: ExerciseType
    let isSelected: Bool
    let theme: BlinkTheme
    let colorScheme: ColorScheme
    let width: CGFloat
    let onTap: () -> Void

    private var fg: Color { .white }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 16) {
                Image(systemName: type.icon)
                    .font(.system(size: 34))
                    .foregroundStyle(isSelected ? theme.accent : fg)
                    .frame(height: 44)

                Text(type.rawValue)
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(fg)

                Text(type.headline)
                    .font(.system(size: 14))
                    .foregroundStyle(fg.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)

                Text(type.shortBenefit)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(theme.accent.opacity(isSelected ? 1 : 0.9))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .padding(.horizontal, 14)
            .frame(width: width)
            .frame(height: max(width * 0.92, 200))
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(fg.opacity(isSelected ? 0.2 : 0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
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
    @State private var contourDemoLoop: CGImage?     // the isolated target shape
    @State private var contourDemoField: CGImage?    // the same loop hidden in noise
    @State private var crowdingDemoImage: CGImage?   // an example target + flankers

    // Illustrative demo patch: a fixed 96-pt disc showing the mid SF level, with
    // the SAME cycles-per-patch / σ=λ geometry the real trial uses, so the
    // preview matches the actual stimulus (just larger and higher-contrast).
    private let demoSize: CGFloat = 96
    private let demoCyclesPerPatch: Double = 9
    private var demoCPP: Double { demoCyclesPerPatch / Double(demoSize) }
    private var demoSigma: Double { 1.0 / demoCPP }        // σ = λ = demoSize / cycles

    var body: some View {
        GeometryReader { geo in
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
                VStack(alignment: .center, spacing: 32) {
                    demoSection
                    Divider().background(fg.opacity(0.15))
                    instructionSection("How to play", "hand.tap", state.exerciseType.howToPlay)
                    Divider().background(fg.opacity(0.15))
                    instructionSection("How this helps", "brain.head.profile", state.exerciseType.benefit)
                }
                .padding(.vertical, 34)
                .padding(.horizontal, 32)
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

                Button {
                    state.showScience()
                } label: {
                    Label("The science & sources", systemImage: "text.book.closed")
                        .font(.system(size: 13))
                        .foregroundStyle(fg.opacity(0.75))
                }
                .buttonStyle(.plain)
                .padding(.top, 16)
                .padding(.bottom, 24)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 40)
            .frame(minHeight: geo.size.height)
        }
        }
    }

    /// One titled section of the instructions card, centered.
    private func instructionSection(_ title: String, _ icon: String, _ text: String) -> some View {
        VStack(alignment: .center, spacing: 13) {
            Label(title, systemImage: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(fg)
            Text(text)
                .font(.system(size: 14))
                .foregroundStyle(fg)
                .lineSpacing(5)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
    }

    /// A labelled two-panel example of one trial — one flash holds the pattern,
    /// the other is plain gray — so you know what to look for before the real
    /// (fainter, briefer) stimulus.
    private var demoSection: some View {
        VStack(alignment: .center, spacing: 16) {
            Label("What you'll see", systemImage: "eye")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(fg)

            if state.exerciseType.isContour {
                contourDemoPanel
            } else if state.exerciseType.isCrowding {
                crowdingDemoPanel
            } else {
                HStack(spacing: 28) {
                    demoFlash(label: "First flash", hasTarget: true)
                    demoFlash(label: "Second flash", hasTarget: false)
                }
                .padding(.vertical, 4)
            }

            Text(demoCaption)
                .font(.system(size: 13))
                .foregroundStyle(fg.opacity(0.85))
                .lineSpacing(3)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
    }

    /// Teaches the target BEFORE the noise: the SAME loop shown isolated ("this
    /// is the shape") next to itself hidden in the field ("now find it"). Both
    /// rendered once via `.task` (Δβ = 0, same seed/facing) and cached.
    private var contourDemoPanel: some View {
        HStack(alignment: .top, spacing: 14) {
            demoTile(contourDemoLoop, "The loop", "little patches lined up into a closed outline with one pointed end")
            Image(systemName: "arrow.right")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(fg.opacity(0.5))
                .padding(.top, 84)
            demoTile(contourDemoField, "…hidden in here", "the rest point every which way")
        }
        .task(id: state.exerciseType) {
            guard state.exerciseType.isContour else { return }
            if contourDemoLoop == nil {
                contourDemoLoop = await Task.detached(priority: .userInitiated) {
                    ContourFieldRenderer.render(sizePt: 200, scale: 2, jitterRadians: 0,
                                                facing: .right, seed: 99, contourOnly: true)
                }.value
            }
            if contourDemoField == nil {
                contourDemoField = await Task.detached(priority: .userInitiated) {
                    ContourFieldRenderer.render(sizePt: 200, scale: 2, jitterRadians: 0,
                                                facing: .right, seed: 99)
                }.value
            }
        }
    }

    /// Fixation cross + an example (uncrowded) target-and-flankers off to the
    /// side, so you learn what to read and where. Rendered once, cached.
    private var crowdingDemoPanel: some View {
        HStack(spacing: 26) {
            VStack(spacing: 6) {
                FixationCross(length: 22, thickness: 2.5).frame(width: 40, height: 150)
                Text("stare here")
                    .font(.system(size: 11)).foregroundStyle(fg.opacity(0.7))
            }
            VStack(spacing: 6) {
                Group {
                    if let cg = crowdingDemoImage {
                        Image(cg, scale: 1, label: Text("example"))
                            .resizable().interpolation(.high)
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 240, height: 150)
                    } else {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(white: GaborDisplayConfig.meanLuminanceGray))
                            .frame(width: 240, height: 150)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 10))
                Text("read the MIDDLE patch")
                    .font(.system(size: 11)).foregroundStyle(fg.opacity(0.7))
            }
        }
        .task(id: state.exerciseType) {
            guard state.exerciseType.isCrowding, crowdingDemoImage == nil else { return }
            crowdingDemoImage = await Task.detached(priority: .userInitiated) {
                CrowdingRenderer.render(patchPt: 60, spacingPt: 130, tiltSign: 1,
                                        flankerA: 1.0, flankerB: -0.5, flankers: true, scale: 2)?.image
            }.value
        }
    }

    private func demoTile(_ cg: CGImage?, _ title: String, _ sub: String) -> some View {
        VStack(spacing: 8) {
            Group {
                if let cg {
                    Image(cg, scale: 1, label: Text(title))
                        .resizable().interpolation(.high)
                        .frame(width: 190, height: 190)
                } else {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(white: GaborDisplayConfig.meanLuminanceGray))
                        .frame(width: 190, height: 190)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(fg.opacity(0.15), lineWidth: 1))

            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(fg)
            Text(sub)
                .font(.system(size: 11))
                .foregroundStyle(fg.opacity(0.7))
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .frame(width: 190)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var demoCaption: String {
        switch state.exerciseType {
        case .detection:
            "Only one flash holds a striped pattern — here, the first, so you'd choose First. In the real exercise it's much fainter and appears only briefly."
        case .contour:
            "In the loop, the little stripes line up end-to-end to trace a smooth closed outline — like a dotted egg with one pointed end. Every other patch points at random. Find the loop, then choose which way its point faces. Each round it hides a little better."
        case .crowding:
            "Keep your eyes on the cross. The three patches flash briefly to the side; the two outer ones are random clutter. Read only the MIDDLE one — is it leaning left or right? Each round the clutter creeps closer, making it harder."
        }
    }

    private func demoFlash(label: String, hasTarget: Bool) -> some View {
        VStack(spacing: 8) {
            GaborPatchView(
                size: demoSize,
                contrast: hasTarget ? 0.9 : 0,
                spatialFrequencyCyclesPerPoint: demoCPP,
                orientation: 0,
                sigmaPoints: demoSigma
            )
            .frame(width: demoSize, height: demoSize)
            .clipShape(Circle())
            .overlay(Circle().stroke(fg.opacity(0.2), lineWidth: 1))

            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(fg)
        }
    }
}

// MARK: - The Science

/// Cites the vision-science this exercise is built on and states, plainly, the
/// limits of what it can claim — the sources and caveats surfaced in-app.
private struct SciencePhase: View {
    let theme: BlinkTheme
    let colorScheme: ColorScheme
    let onBack: () -> Void

    private var fg: Color { .white }

    /// Real, verified references (DOIs web-checked). Each row links to the paper
    /// via its DOI. The stimulus (a Gabor patch), the training paradigm
    /// (perceptual learning / lateral masking), and the measurement method
    /// (forced-choice staircase) each rest on these.
    private let sources: [(text: String, doi: String)] = [
        ("Gabor, D. (1946). Theory of communication. J. Institution of Electrical Engineers, 93, 429–457.", "10.1049/ji-3-2.1946.0074"),
        ("Campbell, F. W., & Robson, J. G. (1968). Application of Fourier analysis to the visibility of gratings. J. Physiology, 197, 551–566.", "10.1113/jphysiol.1968.sp008574"),
        ("Polat, U., & Sagi, D. (1993). Lateral interactions between spatial channels: suppression and facilitation revealed by lateral masking experiments. Vision Research, 33, 993–999.", "10.1016/0042-6989(93)90081-7"),
        ("Polat, U., Ma-Naim, T., Belkin, M., & Sagi, D. (2004). Improving vision in adult amblyopia by perceptual learning. PNAS, 101, 6692–6697.", "10.1073/pnas.0401200101"),
        ("Polat, U., Schor, C., Tong, J.-L., Zomet, A., Lev, M., Yehezkel, O., Sterkin, A., & Levi, D. M. (2012). Training the brain to overcome the effect of aging on the human eye. Scientific Reports, 2, 278.", "10.1038/srep00278"),
        ("Camilleri, R., Pavan, A., Ghin, F., Battaglini, L., & Campana, G. (2014). Improvement of uncorrected visual acuity and contrast sensitivity with perceptual learning and tRNS in individuals with mild myopia. Frontiers in Psychology, 5, 1234.", "10.3389/fpsyg.2014.01234"),
        ("Levitt, H. (1971). Transformed up–down methods in psychoacoustics. J. Acoustical Society of America, 49, 467–477.", "10.1121/1.1912375"),
        ("Pelli, D. G., & Bex, P. (2013). Measuring contrast sensitivity. Vision Research, 90, 10–14.", "10.1016/j.visres.2013.04.015"),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text("The science")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(fg)
                    .padding(.top, 28)

                section("What this is", """
                    The flashing pattern is a Gabor patch — a sinusoidal grating under a \
                    Gaussian envelope (Gabor 1946), the standard stimulus for probing \
                    contrast sensitivity (Campbell & Robson 1968). Repeatedly judging \
                    faint, briefly-shown patches is "perceptual learning": with practice \
                    the visual system detects lower-contrast patterns, an effect studied \
                    in amblyopia, aging, and myopia (Polat & Sagi 1993; Polat 2004, 2012; \
                    Camilleri 2014). Difficulty is set by a forced-choice staircase that \
                    homes in on your threshold (Levitt 1971).
                    """)

                section("Honest about the numbers", """
                    Sizes and spatial-frequency levels here are RELATIVE, not calibrated \
                    degrees or cycles-per-degree: the app can't know your screen's exact \
                    dimensions or your viewing distance, both of which real experiments \
                    fix and measure. The contrast is computed in linear luminance (Pelli \
                    & Bex 2013), so the threshold you see is a meaningful relative index — \
                    but not an absolute, cross-device photometric value.
                    """)

                section("Wellness, not treatment", """
                    The vision improvements in the studies below came from supervised, \
                    multi-week courses — dozens of sessions over months. Occasional \
                    break-time sessions are here for engagement and eye-rest, not as a \
                    treatment, and this exercise is not a medical device.
                    """)

                VStack(alignment: .leading, spacing: 12) {
                    Label("Sources", systemImage: "text.book.closed")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(fg)
                    ForEach(sources, id: \.doi) { s in
                        Link(destination: URL(string: "https://doi.org/\(s.doi)")!) {
                            (Text(s.text).foregroundStyle(fg.opacity(0.85))
                             + Text("  ↗").foregroundStyle(theme.accent))
                                .font(.system(size: 12))
                                .fixedSize(horizontal: false, vertical: true)
                                .lineSpacing(2)
                                .multilineTextAlignment(.leading)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 14).fill(fg.opacity(0.08)))

                Button {
                    onBack()
                } label: {
                    Text("Back")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(fg)
                        .frame(width: 120, height: 40)
                        .background(fg.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .padding(.top, 6)
                .padding(.bottom, 28)
            }
            .frame(maxWidth: 640, alignment: .leading)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 40)
        }
    }

    private func section(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(fg)
            Text(body)
                .font(.system(size: 14))
                .foregroundStyle(fg.opacity(0.9))
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Contour Trial

/// The contour-integration trial: a full field of Gabors (rendered once per
/// trial on a background thread) with a hidden loop; the observer picks which
/// way the loop's pinched end points. Single presentation — no temporal
/// two-interval flow, so it is a sibling of `TrialPhase`, not a branch of it.
struct ContourTrialView: View {
    @ObservedObject var state: GaborExerciseState
    let theme: BlinkTheme
    var feedbackCorrect: Bool?
    /// Test/preview hook: a pre-rendered field to bypass the async render.
    var previewField: ContourField? = nil

    @State private var rendered: (seed: UInt64, field: ContourField)?
    @Environment(\.displayScale) private var displayScale
    private let fg = Color(white: 0.12)

    var body: some View {
        GeometryReader { geo in
            let fieldPt = min(geo.size.width, geo.size.height) * 0.86
            ZStack {
                // The rendered field (blends into the mean-gray screen).
                if let field = previewField ?? (rendered?.seed == state.contourSeed ? rendered?.field : nil) {
                    ContourFieldView(field: field)
                        .opacity(feedbackCorrect != nil ? 0.35 : 1.0)
                }

                if let correct = feedbackCorrect {
                    FeedbackOverlay(correct: correct)
                }

                // Minimal progress, top.
                VStack {
                    Text("\(state.currentTrial) / \(state.totalTrials)")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(fg.opacity(0.55))
                        .padding(.top, 20)
                    Spacer()
                }

                // Left / Right response, at the bottom over the field.
                if case .response = state.stage, feedbackCorrect == nil {
                    VStack {
                        Spacer()
                        responseControls
                            .padding(20)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color(white: 0.5).opacity(0.55))
                            )
                            .padding(.bottom, 28)
                    }
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .task(id: state.contourSeed) {
                await renderField(sizePt: fieldPt)
            }
        }
    }

    private func renderField(sizePt: CGFloat) async {
        let scale = displayScale
        let jitter = state.contourJitterRad
        let facing = state.contourFacing
        let seed = state.contourSeed
        let cg = await Task.detached(priority: .userInitiated) {
            ContourFieldRenderer.render(sizePt: sizePt, scale: scale,
                                        jitterRadians: jitter, facing: facing, seed: seed)
        }.value
        guard let cg else { return }
        rendered = (seed, ContourField(image: cg, facing: facing, sizePt: sizePt))
    }

    private var responseControls: some View {
        VStack(spacing: 12) {
            Text("Which way does the loop point?")
                .font(.system(size: 15))
                .foregroundStyle(fg)

            HStack(spacing: 20) {
                ResponseButton(label: "Left", icon: "arrow.left", theme: theme, colorScheme: .dark) {
                    state.submitContourResponse(.left)
                }
                .keyboardShortcut(.leftArrow, modifiers: [])
                ResponseButton(label: "Right", icon: "arrow.right", theme: theme, colorScheme: .dark) {
                    state.submitContourResponse(.right)
                }
                .keyboardShortcut(.rightArrow, modifiers: [])
            }

            Text("or press ← / →")
                .font(.system(size: 11))
                .foregroundStyle(fg.opacity(0.7))
        }
    }
}

// MARK: - Crowding Trial

/// The crowding trial: fixation cross held dead center; a small tilted target
/// (± two flankers) flashes briefly at eccentricity E to one side, then a
/// backward mask, then a Leans-left / Leans-right response. Single look — a
/// sibling of TrialPhase, not a branch.
struct CrowdingTrialView: View {
    @ObservedObject var state: GaborExerciseState
    let theme: BlinkTheme
    var feedbackCorrect: Bool?
    /// Test/preview hook: a pre-rendered stimulus so the async render can be
    /// bypassed for a deterministic snapshot.
    var previewStimulus: CrowdingStimulus? = nil

    @State private var rendered: (trial: Int, stim: CrowdingStimulus)?
    @Environment(\.displayScale) private var displayScale
    private let fg = Color(white: 0.12)

    // Small peripheral target (much smaller than the detection patch), placed
    // ~4 target-widths out, capped so the widest triplet stays on-screen.
    private func patch(_ size: CGSize) -> CGFloat {
        min(max(0.08 * min(size.width, size.height), 56), 140)
    }
    private func ecc(_ size: CGSize, _ s: CGFloat) -> CGFloat {
        min(4 * s, (0.5 * size.width - s) / 1.8)   // 1.8 = 1 + b_start(0.8)
    }

    var body: some View {
        GeometryReader { geo in
            let s = patch(geo.size)
            let E = ecc(geo.size, s)
            let dir: CGFloat = state.crowdingSide == .left ? -1 : 1
            let cpp = 4.0 / Double(s)
            let sig = Double(s) / 4.0
            ZStack {
                // Prominent central anchor — the whole task is "keep your eyes
                // here while the target flashes to the side", so it must be
                // unmistakably the thing to fixate.
                FixationCross(length: 48, thickness: 6)

                if case .interval = state.stage,
                   let stim = previewStimulus ?? (rendered?.trial == state.currentTrial ? rendered?.stim : nil) {
                    CrowdingStimulusView(stimulus: stim).offset(x: dir * E)
                }
                if case .mask = state.stage {
                    GaborMaskView(size: s * 1.8, contrast: 0.9,
                                  spatialFrequencyCyclesPerPoint: cpp, sigmaPoints: sig)
                        .clipShape(Circle())
                        .offset(x: dir * E)
                }
                if let correct = feedbackCorrect {
                    FeedbackOverlay(correct: correct)
                }

                VStack {
                    Text("\(state.currentTrial) / \(state.totalTrials)")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(fg.opacity(0.55))
                        .padding(.top, 20)
                    Spacer()
                }

                if case .response = state.stage, feedbackCorrect == nil {
                    VStack {
                        Spacer()
                        responseControls
                            .padding(20)
                            .background(RoundedRectangle(cornerRadius: 16).fill(Color(white: 0.5).opacity(0.55)))
                            .padding(.bottom, 28)
                    }
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .task(id: state.currentTrial) { await renderStim(s: s, E: E) }
        }
    }

    private func renderStim(s: CGFloat, E: CGFloat) async {
        let spacing = CGFloat(state.crowdingB) * E
        let scale = displayScale
        let tilt = state.crowdingTiltSign
        let fA = state.crowdingFlankerA, fB = state.crowdingFlankerB
        let flankers = !state.crowdingIsCatch
        let trial = state.currentTrial
        let stim = await Task.detached(priority: .userInitiated) {
            CrowdingRenderer.render(patchPt: s, spacingPt: spacing, tiltSign: tilt,
                                    flankerA: fA, flankerB: fB, flankers: flankers, scale: scale)
        }.value
        if let stim { rendered = (trial, stim) }
    }

    private var responseControls: some View {
        VStack(spacing: 12) {
            Text("Which way does the middle patch lean?")
                .font(.system(size: 15))
                .foregroundStyle(fg)

            HStack(spacing: 20) {
                ResponseButton(label: "Leans left", icon: "arrow.left", theme: theme, colorScheme: .dark) {
                    state.submitTilt(-1)
                }
                .keyboardShortcut(.leftArrow, modifiers: [])
                ResponseButton(label: "Leans right", icon: "arrow.right", theme: theme, colorScheme: .dark) {
                    state.submitTilt(1)
                }
                .keyboardShortcut(.rightArrow, modifiers: [])
            }

            Text("or press ← / →")
                .font(.system(size: 11))
                .foregroundStyle(fg.opacity(0.7))
        }
    }
}

// MARK: - Trial Phase

private struct TrialPhase: View {
    @ObservedObject var state: GaborExerciseState
    let theme: BlinkTheme
    var feedbackCorrect: Bool?

    private let fg: Color = Color(white: 0.12)

    /// High-contrast flankers / mask.
    private let boldContrast: Double = 0.9

    // Screen-proportional sizing. The patch is a fraction of the field's shorter
    // side (the exercise runs fullscreen), clamped — so it scales WITH the
    // display rather than a fixed 4° that vanishes on a large screen. The carrier
    // and envelope are then derived to hold a FIXED number of cycles per patch at
    // σ=λ, so the Gabor looks identical at any size; only the stripe fineness
    // (the SF level) changes between sessions. (Fredericksen, Bex & Verstraten
    // 1997 — a Gabor is fully specified by its cycle count and σ/λ, not by an
    // uncalibrated absolute size.)
    private static let patchScreenFraction: CGFloat = 0.30
    private static let minPatchPt: CGFloat = 180
    private static let maxPatchPt: CGFloat = 460

    private struct Metrics {
        let patch: CGFloat
        let cyclesPerPoint: Double
        let sigma: Double                // σ = λ
    }

    private func metrics(for size: CGSize) -> Metrics {
        let minDim = min(size.width, size.height)
        let patch = min(max(minDim * Self.patchScreenFraction, Self.minPatchPt), Self.maxPatchPt)
        let cyclesPerPatch = Self.cyclesPerPatch(forSF: state.sessionSF)
        let cpp = cyclesPerPatch / Double(patch)          // cycles per point
        let sigma = 1.0 / cpp                             // λ (σ = λ)
        return Metrics(patch: patch, cyclesPerPoint: cpp, sigma: sigma)
    }

    /// `sessionSF` is a nominal/relative spatial-frequency LEVEL (units are not
    /// calibrated — see the in-app "The science" note). Map it to a fixed number
    /// of carrier cycles across the patch: ≥6 keeps σ=λ with the clip radius ≥3σ,
    /// so the Gaussian has faded and there is no disc edge. Higher level = finer
    /// stripes.
    private static func cyclesPerPatch(forSF sf: Double) -> Double {
        switch sf {
        case ..<2.0: return 6
        case ..<4.5: return 9
        default:     return 13
        }
    }

    var body: some View {
        GeometryReader { geo in
            let m = metrics(for: geo.size)
            ZStack {
                // The stimulus owns dead center of the whole field, so the
                // fixation point, aperture ring, and pattern share ONE anchor
                // that never moves — clean mean-gray everywhere else, the way a
                // real detection trial looks.
                ZStack {
                    stimulus(m)
                        .opacity(feedbackCorrect != nil ? 0.4 : 1.0)

                    if let correct = feedbackCorrect {
                        FeedbackOverlay(correct: correct)
                    }
                }
                .frame(width: m.patch, height: m.patch)

                // Minimal progress, muted, at the top edge.
                VStack {
                    Text("\(state.currentTrial) / \(state.totalTrials)")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(fg.opacity(0.45))
                        .padding(.top, 28)
                    Spacer()
                }

                // The answer prompt sits just under the stimulus (not pinned to
                // the screen bottom). Overlay, so showing it never nudges center.
                if case .response = state.stage, feedbackCorrect == nil {
                    responseControls
                        .fixedSize()
                        .offset(y: m.patch / 2 + 96)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }

    // MARK: Stimulus (switches on the trial stage)

    @ViewBuilder
    private func stimulus(_ m: Metrics) -> some View {
        switch state.stage {
        case .fixation, .gap, .response:
            fixation(m)
        case .interval(let i):
            interval(i, m)
        case .mask:
            GaborMaskView(
                size: m.patch,
                contrast: boldContrast,
                spatialFrequencyCyclesPerPoint: m.cyclesPerPoint,
                sigmaPoints: m.sigma
            )
            .clipShape(Circle())
        case .field:
            // Contour uses ContourTrialView, never TrialPhase; unreachable here.
            fixation(m)
        }
    }

    /// Fixation mark sized relative to the (screen-proportional) patch, so its
    /// angular size no longer drifts with the display. High-contrast near-black
    /// ink on the mean-gray field. (Thaler et al. 2013 — a small high-contrast
    /// central mark; a bullseye+crosshair is optimal, a plain cross is close.)
    private func fixation(_ m: Metrics) -> some View {
        let len = min(max(m.patch * 0.09, 14), 40)
        return FixationCross(length: len, thickness: max(len * 0.12, 1.5))
    }

    /// One interval's flash. A faint aperture ring marks BOTH flash windows (so
    /// the empty interval is perceptible) concentric with fixation; the target
    /// interval also shows the Gabor centered inside it.
    private func interval(_ i: Int, _ m: Metrics) -> some View {
        ZStack {
            apertureRing(m)
            if state.isTargetInterval(i) {
                patch(m)
            }
        }
    }

    /// A faint hairline circle at the patch's edge (radius patchSize/2 ≥ 3σ, so
    /// it sits outside the Gabor's Gaussian and never masks it) that flashes on
    /// during each detection interval to mark the flash window — a real Gabor has
    /// no outline, so this is kept minimal and is identical in both intervals so
    /// it can't cue the answer. (The pure-convention marker is an auditory beep;
    /// the ring is retained as a muted-system fallback — see "The science".)
    private func apertureRing(_ m: Metrics) -> some View {
        Circle()
            .strokeBorder(Color(white: 0.4), lineWidth: 1.5)
            .frame(width: m.patch, height: m.patch)
    }

    private func patch(_ m: Metrics) -> some View {
        GaborPatchView(
            size: m.patch,
            contrast: state.staircase.currentContrast,
            spatialFrequencyCyclesPerPoint: m.cyclesPerPoint,
            orientation: state.trialOrientation,
            sigmaPoints: m.sigma                      // σ = λ
        )
        .clipShape(Circle())
    }

    // MARK: Response

    /// The answer prompt + First/Second buttons, grouped as one compact unit so
    /// it can be placed right under the stimulus.
    private var responseControls: some View {
        VStack(spacing: 14) {
            Text("Which flash had the pattern?")
                .font(.system(size: 15))
                .foregroundStyle(fg)

            HStack(spacing: 20) {
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
                StatRow(label: state.primaryMetricLabel, value: state.primaryMetricValue, fg: fg)
                if state.showsSpatialFrequency {
                    StatRow(label: "Spatial frequency", value: state.sessionSFDisplay, fg: fg)
                }
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
