import SwiftUI

struct GaborExerciseView: View {
    @ObservedObject var state: GaborExerciseState
    let theme: BlinkTheme
    let onDismiss: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea(.all)

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

                ExerciseFooter(onShowDisclaimer: { state.showDisclaimer() })
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
                .foregroundStyle(.secondary)

            Text("Before You Start")
                .font(.system(size: 26, weight: .semibold))

            Text("""
                This exercise is for general wellness and entertainment purposes only. \
                It is not a medical device, does not diagnose or treat any condition, \
                and is not a substitute for professional eye care.

                Consult an eye care professional before starting any vision training \
                program. Results may vary. If you experience discomfort, stop immediately.
                """)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 500)
                .lineSpacing(3)

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

            Text("Train your visual cortex with Gabor patch exercises")
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
            .frame(maxWidth: 720)

            Spacer()
                .frame(height: 40)

            Button {
                state.showInstructions()
            } label: {
                Text("Continue")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 180, height: 44)
                    .background(theme.accent)
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

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Exercise icon
            Image(systemName: state.exerciseType.icon)
                .font(.system(size: 52))
                .foregroundStyle(theme.accent)
                .padding(.bottom, 20)

            Text(state.exerciseType.rawValue)
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(fg)
                .padding(.bottom, 6)

            Text(state.exerciseType.headline)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(fg)
                .padding(.bottom, 36)

            // Explanation card
            VStack(alignment: .leading, spacing: 24) {
                // What is this?
                VStack(alignment: .leading, spacing: 10) {
                    Label("What is this?", systemImage: "info.circle")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(fg)

                    Text(state.exerciseType.explanation)
                        .font(.system(size: 14))
                        .foregroundStyle(fg)
                        .lineSpacing(4)
                }

                Divider()
                    .background(fg.opacity(0.15))

                // How to play
                VStack(alignment: .leading, spacing: 10) {
                    Label("How to play", systemImage: "hand.tap")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(fg)

                    Text(state.exerciseType.howToPlay)
                        .font(.system(size: 14))
                        .foregroundStyle(fg)
                        .lineSpacing(4)
                }

                Divider()
                    .background(fg.opacity(0.15))

                // How it adapts
                VStack(alignment: .leading, spacing: 10) {
                    Label("Adaptive difficulty", systemImage: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(fg)

                    Text("The pattern gets fainter as you answer correctly, and bolder when you make mistakes. The exercise zeroes in on your contrast threshold — the faintest level you can reliably detect.")
                        .font(.system(size: 14))
                        .foregroundStyle(fg)
                        .lineSpacing(4)
                }
            }
            .padding(28)
            .frame(maxWidth: 560)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(fg.opacity(0.1))
            )

            Spacer()
                .frame(height: 36)

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
                        .foregroundStyle(.white)
                        .frame(width: 180, height: 44)
                        .background(theme.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }

            Spacer()
        }
        .padding(40)
    }
}

// MARK: - Trial Phase

private struct TrialPhase: View {
    @ObservedObject var state: GaborExerciseState
    let theme: BlinkTheme
    var feedbackCorrect: Bool?

    private let fg: Color = .white

    var body: some View {
        VStack(spacing: 24) {
            // Header
            HStack {
                Text("Trial \(state.currentTrial) of \(state.totalTrials)")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(fg.opacity(0.6))
                Spacer()
                Text("Score: \(state.score)/\(state.currentTrial)")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(fg.opacity(0.6))
            }
            .padding(.horizontal, 60)
            .padding(.top, 20)

            ProgressDots(current: state.currentTrial, total: state.totalTrials, theme: theme)
                .padding(.horizontal, 60)

            Spacer()

            // Stimulus — directly on black, no container box
            ZStack {
                stimulusContent
                    .opacity(feedbackCorrect != nil ? 0.4 : 1.0)

                if let correct = feedbackCorrect {
                    FeedbackOverlay(correct: correct)
                }
            }

            Spacer()

            // Instruction hint
            Text(state.exerciseType.howToPlay)
                .font(.system(size: 13))
                .foregroundStyle(fg.opacity(0.4))

            // Response buttons
            if feedbackCorrect == nil {
                responseButtons
                    .padding(.horizontal, 60)
            } else {
                Color.clear.frame(height: 48)
            }

            Spacer()
                .frame(height: 24)
        }
    }

    @ViewBuilder
    private var stimulusContent: some View {
        switch state.exerciseType {
        case .contrastDetection:
            ContrastDetectionStimulus(state: state)
        case .orientationDiscrimination:
            OrientationStimulus(state: state)
        case .flankerMasking:
            FlankerStimulus(state: state)
        }
    }

    @ViewBuilder
    private var responseButtons: some View {
        let dark = ColorScheme.dark
        switch state.exerciseType {
        case .contrastDetection:
            HStack(spacing: 28) {
                ResponseButton(label: "Left", icon: "arrow.left.circle", theme: theme, colorScheme: dark) {
                    state.submitResponse(0)
                }
                ResponseButton(label: "Right", icon: "arrow.right.circle", theme: theme, colorScheme: dark) {
                    state.submitResponse(1)
                }
            }
        case .orientationDiscrimination, .flankerMasking:
            HStack(spacing: 28) {
                ResponseButton(label: "Tilted Left", icon: "arrow.turn.up.left", theme: theme, colorScheme: dark) {
                    state.submitResponse(0)
                }
                ResponseButton(label: "Tilted Right", icon: "arrow.turn.up.right", theme: theme, colorScheme: dark) {
                    state.submitResponse(1)
                }
            }
        }
    }
}

// MARK: - Stimulus Views

private struct ContrastDetectionStimulus: View {
    @ObservedObject var state: GaborExerciseState
    private let patchPointSize: CGFloat = 110

    var body: some View {
        HStack(spacing: 100) {
            patchCircle(hasGabor: state.targetPosition == 0)
            patchCircle(hasGabor: state.targetPosition == 1)
        }
    }

    private func patchCircle(hasGabor: Bool) -> some View {
        Group {
            if hasGabor {
                GaborRenderer.asImage(
                    pointSize: patchPointSize,
                    contrast: state.staircase.currentContrast,
                    spatialFrequency: 0.05,
                    orientation: Double.random(in: 0...(.pi)),
                    phase: Double.random(in: 0...(2 * .pi))
                )
            } else {
                GaborRenderer.plainGrayImage(pointSize: patchPointSize)
            }
        }
        .frame(width: patchPointSize, height: patchPointSize)
        .clipShape(Circle())
        .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 1))
    }
}

private struct OrientationStimulus: View {
    @ObservedObject var state: GaborExerciseState
    private let patchPointSize: CGFloat = 120

    var body: some View {
        GaborRenderer.asImage(
            pointSize: patchPointSize,
            contrast: state.staircase.currentContrast,
            spatialFrequency: 0.05,
            orientation: state.targetOrientation
        )
        .frame(width: patchPointSize, height: patchPointSize)
        .clipShape(Circle())
        .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 1))
    }
}

private struct FlankerStimulus: View {
    @ObservedObject var state: GaborExerciseState
    private let patchPointSize: CGFloat = 100
    private let flankerContrast: Double = 0.8

    var body: some View {
        HStack(spacing: state.flankerDistance) {
            flankerPatch
            GaborRenderer.asImage(
                pointSize: patchPointSize,
                contrast: state.staircase.currentContrast,
                spatialFrequency: 0.05,
                orientation: state.targetOrientation
            )
            .frame(width: patchPointSize, height: patchPointSize)
            .clipShape(Circle())
            .overlay(Circle().stroke(Color.white.opacity(0.3), lineWidth: 1))
            flankerPatch
        }
    }

    private var flankerPatch: some View {
        GaborRenderer.asImage(
            pointSize: patchPointSize,
            contrast: flankerContrast,
            spatialFrequency: 0.05,
            orientation: 0
        )
        .frame(width: patchPointSize, height: patchPointSize)
        .clipShape(Circle())
        .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 1))
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
                StatRow(label: "Contrast Threshold", value: state.thresholdDisplay, fg: fg)
            }
            .padding(24)
            .frame(maxWidth: 340)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(fg.opacity(0.1))
            )

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
                        .foregroundStyle(.white)
                        .frame(width: 120, height: 44)
                        .background(theme.accent)
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

    private var fg: Color { .white }

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

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<min(total, 30), id: \.self) { index in
                Circle()
                    .fill(index < current ? theme.accent : theme.accent.opacity(0.2))
                    .frame(width: dotSize, height: dotSize)
            }
            if total > 30 {
                Text("+\(total - 30)")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var dotSize: CGFloat { total > 25 ? 4 : 6 }
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
    let onShowDisclaimer: () -> Void

    var body: some View {
        let footerColor: Color = .white.opacity(0.4)
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
