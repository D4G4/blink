import SwiftUI

/// Detailed explanation of flow detection — shown from "Learn more" on the flow onboarding page.
struct FlowLearnMoreView: View {
    let theme: BlinkTheme
    let onDismiss: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let fg = Color.primary

        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 36, weight: .light))
                            .foregroundStyle(theme.accent(for: colorScheme))

                        Text("How Flow Detection Works")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 8)

                    // What is flow?
                    sectionHeader("What is flow?")
                    Text("Flow is the state of deep focus where you lose track of time. Blink detects this by analyzing patterns in your input — not what you type, but how you type.")
                        .font(.system(size: 13))
                        .foregroundStyle(fg.opacity(0.8))

                    // Signals
                    sectionHeader("What Blink monitors")

                    signalRow(
                        icon: "keyboard",
                        title: "Keystroke rhythm",
                        detail: "Steady, consistent typing suggests concentration. Bursts with long pauses suggest casual use."
                    )
                    signalRow(
                        icon: "arrow.triangle.swap",
                        title: "App switching",
                        detail: "Staying in one app = focused. Rapidly switching between apps = browsing or distracted."
                    )
                    signalRow(
                        icon: "computermouse",
                        title: "Mouse behavior",
                        detail: "Precise, purposeful movements signal engagement. Random scrolling suggests consumption."
                    )
                    signalRow(
                        icon: "macwindow",
                        title: "Window stability",
                        detail: "Keeping the same window active for minutes indicates deep work."
                    )
                    signalRow(
                        icon: "app.badge",
                        title: "App context",
                        detail: "Code editors, design tools, and writing apps get a focus bonus. Browsers and social apps don't."
                    )

                    sectionHeader("When Blink pauses automatically")

                    signalRow(
                        icon: "mic",
                        title: "Microphone active",
                        detail: "Any mic usage — calls, dictation, voice recording — pauses the timer. You'll never get a break mid-conversation."
                    )
                    signalRow(
                        icon: "video",
                        title: "Video playing",
                        detail: "Watching YouTube, Netflix, or any video? Timer pauses — you're already resting your focus."
                    )
                    signalRow(
                        icon: "figure.walk",
                        title: "Away from desk",
                        detail: "No input for 3+ minutes? Blink assumes you walked away and silently resets the timer."
                    )

                    // How it affects timing
                    sectionHeader("How it affects your breaks")

                    HStack(spacing: 0) {
                        timerColumn(label: "Normal", duration: "20 min", description: "Default interval")
                        timerColumn(label: "Flow", duration: "30 min", description: "3+ min of focus")
                        timerColumn(label: "Deep Flow", duration: "40 min", description: "15+ min of focus")
                    }
                    .padding(16)
                    .background(Color.primary.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    // Sensitivity
                    sectionHeader("What does sensitivity control?")
                    Text("The sensitivity slider sets how easily Blink recognizes flow. At low sensitivity, only intense coding sessions count. At high sensitivity, even moderate focus extends the timer. The default (70%) works well for most people.")
                        .font(.system(size: 13))
                        .foregroundStyle(fg.opacity(0.8))

                    // Privacy note
                    HStack(spacing: 10) {
                        Image(systemName: "lock.shield")
                            .font(.system(size: 16))
                            .foregroundStyle(theme.accent(for: colorScheme))
                        Text("Blink reads input timing only — never keystrokes, window contents, or personal data.")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(fg.opacity(0.6))
                    }
                    .padding(12)
                    .background(theme.accent(for: colorScheme).opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .padding(.top, 4)
                }
                .padding(24)
            }

            Divider()

            Button {
                onDismiss()
            } label: {
                Text("Got it")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 36)
                    .background(theme.accent(for: colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
            .padding(16)
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(.primary)
            .padding(.top, 4)
    }

    private func signalRow(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(theme.accent(for: colorScheme))
                .frame(width: 28, height: 28)
                .background(theme.accent(for: colorScheme).opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                Text(detail)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func timerColumn(label: String, duration: String, description: String) -> some View {
        VStack(spacing: 4) {
            Text(duration)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(theme.accent(for: colorScheme))
            Text(label)
                .font(.system(size: 12, weight: .semibold))
            Text(description)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview("Flow Learn More") {
    FlowLearnMoreView(theme: .peach, onDismiss: {})
        .frame(width: 480, height: 560)
}
