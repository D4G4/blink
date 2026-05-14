import SwiftUI

/// Detailed explanation of flow detection — shown from "Learn more" on the flow onboarding page.
struct FlowLearnMoreView: View {
    let theme: BlinkTheme
    let onDismiss: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    @State private var sensitivity: Double = 0.7

    private var gapTolerance: Int {
        let t = (sensitivity - 0.4) / (0.9 - 0.4)
        return Int((15 + t * 75).rounded())
    }

    var body: some View {
        let fg = Color.primary
        let accent = theme.accent(for: colorScheme)

        VStack(spacing: 0) {
            // Sticky header: title + slider
            VStack(spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 24, weight: .light))
                        .foregroundStyle(accent)
                    Text("How Flow Detection Works")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                }

                VStack(spacing: 6) {
                    HStack {
                        Text("Low")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                        Slider(value: $sensitivity, in: 0.4...0.9, step: 0.05)
                            .tint(accent)
                        Text("High")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    HStack(spacing: 8) {
                        Text("Sensitivity: \(Int(sensitivity * 100))%")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                        Text("·")
                            .foregroundStyle(.secondary)
                        Text("Pause tolerance: \(gapTolerance)s")
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundStyle(accent)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(.bar)

            Divider()

            // Scrollable content
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    // Core concept
                    sectionHeader("The simple rule")
                    Text("If you've been continuously active — any keyboard or mouse input — with no long pauses, Blink considers you in flow and extends your break interval.")
                        .font(.system(size: 13))
                        .foregroundStyle(fg.opacity(0.8))

                    // How it works
                    sectionHeader("How it decides")

                    VStack(alignment: .leading, spacing: 6) {
                        ruleRow("Active for 3+ minutes", "→ Flow (breaks at 30 min)", accent: accent)
                        ruleRow("In flow for 15+ minutes", "→ Deep Flow (breaks at 40 min)", accent: accent)
                        ruleRow("Pause > \(gapTolerance)s", "→ Flow ends, back to 20 min", accent: accent)
                    }
                    .padding(14)
                    .background(fg.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                    // Dynamic scenarios
                    sectionHeader("Real scenarios at \(Int(sensitivity * 100))%")

                    scenarioRow(
                        icon: "keyboard",
                        title: "Coding with \(gapTolerance - 10)s thinking pauses",
                        detail: "You type, pause \(gapTolerance - 10)s to think, type again. Gap (\(gapTolerance - 10)s) is under your \(gapTolerance)s tolerance.",
                        result: "Flow stays active — timer extends to 30–40 min",
                        accent: accent
                    )
                    scenarioRow(
                        icon: "doc.text",
                        title: "Reading docs for \(gapTolerance + 15)s",
                        detail: "You read without input for \(gapTolerance + 15)s, then start typing. Gap (\(gapTolerance + 15)s) exceeds your \(gapTolerance)s tolerance.",
                        result: "Flow breaks. Timer resets to 20 min",
                        accent: accent
                    )
                    scenarioRow(
                        icon: "arrow.triangle.swap",
                        title: "Switching apps every \(max(gapTolerance - 20, 5))s",
                        detail: "You switch between editor and browser, clicking every \(max(gapTolerance - 20, 5))s. All gaps under \(gapTolerance)s.",
                        result: "Flow stays active — based on input gaps, not which app",
                        accent: accent
                    )
                    scenarioRow(
                        icon: "cup.and.saucer",
                        title: "Getting coffee (away 5 min)",
                        detail: "No input for 5 minutes. Exceeds both \(gapTolerance)s tolerance and 3 min idle threshold.",
                        result: "Timer resets silently — you already rested your eyes",
                        accent: accent
                    )
                    scenarioRow(
                        icon: "mic",
                        title: "On a call",
                        detail: "Mic active. Detected immediately regardless of sensitivity.",
                        result: "Timer pauses. Resumes when call ends",
                        accent: accent
                    )
                    scenarioRow(
                        icon: "brain",
                        title: "Deep in flow, timer fires",
                        detail: "You've been coding for 40 min straight. Timer reaches zero.",
                        result: "Gentle toast — never forces overlay during flow",
                        accent: accent
                    )
                    scenarioRow(
                        icon: "hand.raised",
                        title: "Not in flow, timer fires",
                        detail: "Browsing casually for 20 min. Timer reaches zero.",
                        result: "Fullscreen break — 20s. Esc to skip, → to extend",
                        accent: accent
                    )

                    // Timer summary
                    sectionHeader("Break intervals")

                    HStack(spacing: 0) {
                        timerColumn(label: "Normal", duration: "20 min", description: "Default", accent: accent)
                        timerColumn(label: "Flow", duration: "30 min", description: "3+ min active", accent: accent)
                        timerColumn(label: "Deep Flow", duration: "40 min", description: "15+ min active", accent: accent)
                    }
                    .padding(14)
                    .background(fg.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                    // Privacy
                    HStack(spacing: 10) {
                        Image(systemName: "lock.shield")
                            .font(.system(size: 16))
                            .foregroundStyle(accent)
                        Text("Blink reads input timing only — never keystrokes, window contents, or personal data.")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(fg.opacity(0.6))
                    }
                    .padding(12)
                    .background(accent.opacity(0.08))
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
                    .background(accent)
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

    private func ruleRow(_ condition: String, _ result: String, accent: Color) -> some View {
        HStack(spacing: 8) {
            Text(condition)
                .font(.system(size: 12, weight: .semibold))
            Text(result)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
    }

    private func scenarioRow(icon: String, title: String, detail: String, result: String, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundStyle(accent)
                    .frame(width: 24, height: 24)
                    .background(accent.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
            }
            Text(detail)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            HStack(spacing: 4) {
                Image(systemName: "arrow.right")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(accent)
                Text(result)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(accent)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.primary.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func timerColumn(label: String, duration: String, description: String, accent: Color) -> some View {
        VStack(spacing: 4) {
            Text(duration)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(accent)
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
        .frame(width: 480, height: 700)
}
