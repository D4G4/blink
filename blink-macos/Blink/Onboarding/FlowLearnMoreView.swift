import SwiftUI

/// Detailed explanation of flow detection — shown from "Learn more" on the flow onboarding page.
struct FlowLearnMoreView: View {
    let theme: BlinkTheme
    let onDismiss: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let fg = Color.primary
        let accent = theme.accent(for: colorScheme)

        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 36, weight: .light))
                            .foregroundStyle(accent)

                        Text("How Flow Detection Works")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 4)

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
                        ruleRow("Pause too long", "→ Flow ends, back to 20 min", accent: accent)
                    }
                    .padding(14)
                    .background(fg.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                    // Real scenarios
                    sectionHeader("Real scenarios")

                    scenarioRow(
                        icon: "keyboard",
                        title: "Coding for 10 minutes",
                        detail: "You're typing steadily with short pauses to think (< 60s each). Blink detects flow after 3 minutes. Timer extends to 30 min. After 15 min, deep flow — 40 min.",
                        result: "Break nudge at 30–40 min (gentle toast, not forced)",
                        accent: accent
                    )
                    scenarioRow(
                        icon: "doc.text",
                        title: "Reading docs for 2 minutes, then coding",
                        detail: "You read without touching keyboard for 90 seconds, then start typing. At default sensitivity (60s tolerance), the 90s pause breaks flow.",
                        result: "Flow resets. Timer stays at 20 min until you're active for 3 min again",
                        accent: accent
                    )
                    scenarioRow(
                        icon: "arrow.triangle.swap",
                        title: "Switching between editor and browser",
                        detail: "You switch apps frequently but keep typing and clicking. Every gap is under 60 seconds.",
                        result: "Flow stays active — it's based on input gaps, not which app you're in",
                        accent: accent
                    )
                    scenarioRow(
                        icon: "cup.and.saucer",
                        title: "Getting coffee (away 5 minutes)",
                        detail: "No input for 5 minutes. Blink detects you're away after 3 minutes.",
                        result: "Timer resets silently. No break shown — you already rested your eyes",
                        accent: accent
                    )
                    scenarioRow(
                        icon: "mic",
                        title: "On a Zoom call",
                        detail: "Microphone is active. Blink detects this immediately.",
                        result: "Timer pauses completely. Resumes when the call ends",
                        accent: accent
                    )
                    scenarioRow(
                        icon: "play.rectangle",
                        title: "Watching a YouTube video",
                        detail: "Video is playing in the browser. No keyboard/mouse input.",
                        result: "Timer pauses — you're already looking at a fixed point, not straining focus",
                        accent: accent
                    )
                    scenarioRow(
                        icon: "brain",
                        title: "Deep in flow, timer fires",
                        detail: "You've been coding for 40 minutes straight. Timer reaches zero.",
                        result: "Gentle toast: \"Focused for 40 min — time for a break?\" Auto-dismisses in 7s. Never forces a fullscreen overlay during flow",
                        accent: accent
                    )
                    scenarioRow(
                        icon: "hand.raised",
                        title: "Not in flow, timer fires",
                        detail: "You've been browsing casually for 20 minutes. Timer reaches zero.",
                        result: "Fullscreen break overlay — 20 seconds. Esc to skip, → to extend",
                        accent: accent
                    )
                    
                    // Sensitivity
                    sectionHeader("What \"sensitivity\" controls")
                    Text("The sensitivity slider sets how long you can pause between actions and still stay in flow. At the default (70%), you can think for up to 60 seconds without losing flow.")
                        .font(.system(size: 13))
                        .foregroundStyle(fg.opacity(0.8))

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
