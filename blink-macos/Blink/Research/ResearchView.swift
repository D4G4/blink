import SwiftUI
import AppKit

/// In-app summary of research backing Blink's flow detection and break timing.
/// Presents key findings with data points. Links to full papers for deep dives.
struct ResearchView: View {
    let theme: BlinkTheme
    let onDismiss: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let accent = theme.accent(for: colorScheme)

        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    VStack(spacing: 6) {
                        Image(systemName: "book.closed.fill")
                            .font(.system(size: 32, weight: .light))
                            .foregroundStyle(accent)
                        Text("The Science Behind Blink")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 8)

                    // Finding 1: Blink rate
                    findingCard(
                        number: "01",
                        title: "Your blink rate drops 69% during focused work",
                        keyData: "Normal: 15 blinks/min → Screen work: 5 blinks/min",
                        detail: "When you're typing or doing active screen tasks, your blink rate drops dramatically compared to passive activities. This causes dry eyes, irritation, and fatigue.",
                        source: "Relationship Between Dry Eye Disease and Digital Screen Use",
                        journal: "PMC / Ophthalmology & Therapy, 2021",
                        url: "https://pmc.ncbi.nlm.nih.gov/articles/PMC8439964/",
                        accent: accent
                    )

                    // Finding 2: Incomplete blinks
                    findingCard(
                        number: "02",
                        title: "92% of your blinks become incomplete during focus",
                        keyData: "Baseline: 80% incomplete → Active task: 92% incomplete",
                        detail: "Even when you do blink during focused work, most blinks don't fully close your eyelids. Incomplete blinks fail to refresh the tear film, causing faster evaporation and eye strain.",
                        source: "TFOS Lifestyle: Impact of Digital Environment on Ocular Surface",
                        journal: "ScienceDirect / The Ocular Surface, 2023",
                        url: "https://www.sciencedirect.com/science/article/pii/S1542012423000307",
                        accent: accent
                    )

                    // Finding 3: Active vs passive
                    findingCard(
                        number: "03",
                        title: "Active tasks cause more strain than passive ones",
                        keyData: "Active typing: 5 blinks/min → Passive watching: 16 blinks/min",
                        detail: "Typing, coding, and data entry cause significantly more eye strain than watching videos or reading. The higher the cognitive demand, the fewer you blink. This is why Blink uses keyboard activity as the primary signal for flow detection.",
                        source: "Cognitive Demand, Digital Screens and Blink Rate",
                        journal: "ScienceDirect / Computers in Human Behavior, 2015",
                        url: "https://www.sciencedirect.com/science/article/abs/pii/S0747563215003829",
                        accent: accent
                    )

                    // Finding 4: Interruption timing
                    findingCard(
                        number: "04",
                        title: "Interruptions cost 32% less at natural task boundaries",
                        keyData: "Worst timing: 639ms recovery → Best timing: 485ms recovery",
                        detail: "Research shows that interruptions between subtasks (natural breakpoints) are significantly less disruptive than mid-task interruptions. Blink waits for natural pauses in your typing — a moment between thoughts, not during one.",
                        source: "Opportune Moments for Task Interruptions",
                        journal: "Frontiers in Psychology, 2024",
                        url: "https://pmc.ncbi.nlm.nih.gov/articles/PMC11775001/",
                        accent: accent
                    )

                    // Finding 5: Programming pauses
                    findingCard(
                        number: "05",
                        title: "2–15 second pauses mean you're thinking, not idle",
                        keyData: "2–15s pause = working memory (syntax, logic) → bad time to interrupt",
                        detail: "Keystroke analysis of programmers shows that short pauses (2–15 seconds) indicate active problem-solving in working memory. Longer pauses (30s+) after typing bursts more likely indicate a completed thought — a better moment for a break reminder.",
                        source: "Pausing While Programming: Insights From Keystroke Analysis",
                        journal: "IEEE / ICSE-SEET, 2022",
                        url: "https://ieeexplore.ieee.org/document/9794163/",
                        accent: accent
                    )

                    // Finding 6: Screen time risk
                    findingCard(
                        number: "06",
                        title: "4+ hours of screen time nearly doubles dry eye risk",
                        keyData: "4+ hrs: OR=1.83 → 8+ hrs: OR=1.94 for diagnosed dry eye",
                        detail: "Workers using screens for more than 4 hours daily have nearly twice the risk of dry eye disease. The risk plateaus after 8 hours — suggesting that regular breaks are more important than reducing total screen time.",
                        source: "Dry Eye Disease and Digital Screen Use",
                        journal: "PMC / Ophthalmology & Therapy, 2021",
                        url: "https://pmc.ncbi.nlm.nih.gov/articles/PMC8439964/",
                        accent: accent
                    )

                    // Bottom note
                    Text("Blink uses these findings to detect when you're focused, wait for natural thought boundaries, and remind you to rest your eyes — without interrupting your flow.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .padding(.top, 8)
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

    // MARK: - Finding Card

    private func findingCard(
        number: String,
        title: String,
        keyData: String,
        detail: String,
        source: String,
        journal: String,
        url: String,
        accent: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Number + title
            HStack(alignment: .top, spacing: 10) {
                Text(number)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(accent)
                    .frame(width: 22)
                Text(title)
                    .font(.system(size: 14, weight: .bold))
            }

            // Key data point
            Text(keyData)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundStyle(accent)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(accent.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 6))

            // Detail
            Text(detail)
                .font(.system(size: 12))
                .foregroundStyle(.primary)

            // Source + link
            HStack(spacing: 4) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(source)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text(journal)
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                Button {
                    NSWorkspace.shared.open(URL(string: url)!)
                } label: {
                    HStack(spacing: 3) {
                        Text("Full paper")
                            .font(.system(size: 10, weight: .medium))
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 8, weight: .bold))
                    }
                    .foregroundStyle(accent)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(Color.primary.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

#Preview("Research — Light") {
    ResearchView(theme: .peach, onDismiss: {})
        .frame(width: 480, height: 700)
}

#Preview("Research — Dark") {
    ResearchView(theme: .midnight, onDismiss: {})
        .frame(width: 480, height: 700)
        .preferredColorScheme(.dark)
}
