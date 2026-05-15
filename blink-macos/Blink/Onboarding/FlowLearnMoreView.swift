import SwiftUI

/// Detailed explanation of flow detection — shown from "Learn more" on the flow onboarding page.
struct FlowLearnMoreView: View {
    let theme: BlinkTheme
    let onDismiss: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("flowSensitivity") private var sensitivity: Double = 0.7

    private var presetLabel: String {
        switch sensitivity {
        case ..<0.55: return "Eye health"
        case ..<0.75: return "Balanced"
        default: return "Deep work"
        }
    }

    // Threshold for extension: inputs/min needed to count as focused work
    private var extensionThreshold: Int {
        Int((sensitivity * 10).rounded()) // Eye health ~5, Balanced ~7, Deep work ~9
    }

    // How many extensions allowed
    private var maxExtensions: Int {
        sensitivity < 0.55 ? 0 : sensitivity < 0.75 ? 1 : 2
    }

    private var maxTimer: String {
        switch maxExtensions {
        case 0: return "20 min"
        case 1: return "30 min"
        default: return "40 min"
        }
    }

    // Sensitivity-dependent scenario results
    private var codingResult: String {
        switch sensitivity {
        case ..<0.55: return "Break at 20 min — eye health prioritized"
        case ..<0.75: return "Extended to 30 min → gentle nudge when ready"
        default:      return "Extended up to 40 min → minimal interruption"
        }
    }

    private var designResult: String {
        switch sensitivity {
        case ..<0.55: return "Break at 20 min — clicks alone don't extend"
        case ..<0.75: return "Extended to 30 min — creative app detected"
        default:      return "Extended up to 40 min — deep creative work"
        }
    }

    private var browsingResult: String {
        switch sensitivity {
        case ..<0.55: return "Break overlay at 20 min"
        case ..<0.75: return "Break overlay at 20 min — scrolling isn't focus"
        default:      return "Gentle nudge — low activity, not worth interrupting"
        }
    }

    private var readingResult: String {
        switch sensitivity {
        case ..<0.55: return "Break at 20 min — your eyes still need rest"
        case ..<0.75: return "Gentle nudge to rest your eyes"
        default:      return "Silent — barely any input detected"
        }
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
                        Text("Eye health")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                        Slider(value: $sensitivity, in: 0.4...0.9, step: 0.05)
                            .tint(accent)
                        Text("Deep work")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    Text(presetLabel)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(accent)
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
                    sectionHeader("How it works")
                    Text("Blink learns your work rhythm for 20 minutes. When the timer fires, it looks at how you've been working and makes one decision: extend your session, remind you to take a break, or stay quiet.")
                        .font(.system(size: 13))
                        .foregroundStyle(.primary)

                    // Scenarios first — most useful
                    sectionHeader("Real scenarios — \(presetLabel) (\(Int(sensitivity * 100))%)")

                    scenarioRow(
                        icon: "keyboard",
                        title: "Coding for 20 minutes",
                        detail: "~\(extensionThreshold + 3) inputs/min — steady typing, low app switching. Easily above the \(extensionThreshold)/min threshold.",
                        result: codingResult,
                        accent: accent
                    )
                    scenarioRow(
                        icon: "paintbrush.pointed",
                        title: "Designing in Figma",
                        detail: "~\(extensionThreshold + 1) inputs/min — clicks and drags in a creative app. Clears \(extensionThreshold)/min with app bonus.",
                        result: designResult,
                        accent: accent
                    )
                    scenarioRow(
                        icon: "globe",
                        title: "Browsing Reddit for 20 minutes",
                        detail: "~\(max(extensionThreshold - 3, 2)) inputs/min — mostly scrolling, some clicks. Below \(extensionThreshold)/min threshold.",
                        result: browsingResult,
                        accent: accent
                    )
                    scenarioRow(
                        icon: "message",
                        title: "Chatting occasionally while away",
                        detail: "A few messages typed, some scrolling. Mostly away from screen.",
                        result: "Too little activity → silent reset, no interruption",
                        accent: accent
                    )
                    scenarioRow(
                        icon: "doc.text",
                        title: "Reading a long document",
                        detail: "Occasional scrolling, no typing. Still staring at screen.",
                        result: readingResult,
                        accent: accent
                    )
                    scenarioRow(
                        icon: "cup.and.saucer",
                        title: "Getting coffee (away 3+ min)",
                        detail: "No input at all for 3 minutes.",
                        result: "Idle detected → timer resets silently, fresh start when you return",
                        accent: accent
                    )
                    scenarioRow(
                        icon: "mic",
                        title: "On a Zoom call",
                        detail: "Mic active — detected immediately.",
                        result: "Timer pauses completely. Resumes when call ends",
                        accent: accent
                    )

                    // What it decides
                    sectionHeader("What Blink decides")

                    VStack(alignment: .leading, spacing: 6) {
                        ruleRow(">\(extensionThreshold) inputs/min + focused", "→ Extend to \(maxTimer) (max \(maxExtensions) extensions)", accent: accent)
                        ruleRow("5–\(extensionThreshold) inputs/min", "→ Break overlay (20s)", accent: accent)
                        ruleRow("1–5 inputs/min", "→ Gentle nudge (toast)", accent: accent)
                        ruleRow("<1 input/min", "→ Silent reset (no interruption)", accent: accent)
                    }
                    .padding(14)
                    .background(Color.primary.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                    // What it looks at
                    sectionHeader("What Blink looks at")

                    VStack(alignment: .leading, spacing: 6) {
                        ruleRow("Typing intensity", "→ Strongest signal of focused work", accent: accent)
                        ruleRow("Click frequency", "→ Designers click a lot — that counts", accent: accent)
                        ruleRow("App switching", "→ Fewer switches = more focused", accent: accent)
                        ruleRow("What app you're in", "→ Editors and design tools get a bonus", accent: accent)
                        ruleRow("Scroll without typing", "→ Consumption, not creation", accent: accent)
                    }
                    .padding(14)
                    .background(Color.primary.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                    // Timer summary
                    sectionHeader("Break intervals")

                    HStack(spacing: 0) {
                        timerColumn(label: "Normal", duration: "20 min", description: "Default", accent: accent)
                        timerColumn(label: "Extended", duration: "30 min", description: "1st extension", accent: accent)
                        timerColumn(label: "Max", duration: "40 min", description: "2nd extension", accent: accent)
                    }
                    .padding(14)
                    .background(Color.primary.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                    // Privacy
                    HStack(spacing: 10) {
                        Image(systemName: "lock.shield")
                            .font(.system(size: 16))
                            .foregroundStyle(accent)
                        Text("Blink learns your work rhythm only — never keystrokes, window contents, or personal data.")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.primary)
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
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.primary)
            Text(result)
                .font(.system(size: 12))
                .foregroundStyle(.primary)
        }
    }

    private func scenarioRow(icon: String, title: String, detail: String, result: String, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundStyle(accent)
                    .frame(width: 24, height: 24)
                    .background(accent.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                Text(title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.primary)
            }
            Text(detail)
                .font(.system(size: 12))
                .foregroundStyle(.primary)
            HStack(spacing: 4) {
                Image(systemName: "arrow.right")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(accent)
                Text(result)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(accent)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.primary.opacity(0.06))
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
