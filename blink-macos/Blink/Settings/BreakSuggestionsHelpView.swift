import SwiftUI
import BlinkCore

/// Modal sheet shown from Settings → Break Screen → "Learn more".
/// Explains how the smart break-suggestion picker chooses what to show.
/// Visual: a card per rule with the SF Symbol it ships, the title that
/// appears on the break screen, and a plain-English trigger condition.
struct BreakSuggestionsHelpView: View {
    let theme: BlinkTheme
    let onClose: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    /// One row in the rules list. `trigger` is the human-readable answer
    /// to "when does this show?" — kept tight; the rule ladder itself
    /// lives in `BreakSuggestionPicker.primary(_:)`.
    private struct Rule: Identifiable {
        let id = UUID()
        let suggestion: BreakSuggestion
        let trigger: String
    }

    private var rules: [Rule] {
        [
            Rule(suggestion: .lookFarAway,
                 trigger: "The default — relaxed eyes, no special signal."),
            Rule(suggestion: .breathe,
                 trigger: "You were in sustained focus right before this break — interrupting flow tends to leave the body wound up."),
            Rule(suggestion: .drinkWater,
                 trigger: "Early morning (6–9 AM), when post-sleep dehydration is most useful to address."),
            Rule(suggestion: .getUp,
                 trigger: "You've been seated 45+ minutes, or you've dismissed 2 of the last 3 breaks."),
            Rule(suggestion: .takeAWalk,
                 trigger: "You've been seated 90+ minutes — your body wants more than a stretch."),
            Rule(suggestion: .touchGrass,
                 trigger: "Seated 90+ minutes during the afternoon (2–5 PM) when daylight is still out — a quick step outside resets your eyes too."),
        ]
    }

    var body: some View {
        let accent = theme.accent(for: colorScheme)
        // No ScrollView — ImageRenderer (snapshot tests) doesn't measure
        // ScrollView content correctly and renders it blank. Content is
        // compact enough to fit a fixed frame at default macOS text size.
        VStack(spacing: 0) {
            header(accent: accent)

            VStack(alignment: .leading, spacing: 12) {
                intro

                VStack(spacing: 6) {
                    ForEach(rules) { rule in
                        ruleRow(rule, accent: accent)
                    }
                }

                footer
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .frame(maxHeight: .infinity, alignment: .top)

            Divider()
            footerBar(accent: accent)
        }
        .frame(width: 540, height: 640)
    }

    // MARK: - Pieces

    private func header(accent: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkles")
                .font(.system(size: 18))
                .foregroundStyle(accent)
            Text("Smart Break Suggestions")
                .font(.system(size: 17, weight: .semibold))
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(accent.opacity(0.08))
    }

    private var intro: some View {
        Text("Instead of always saying \u{201C}Look at something far away,\u{201D} Blink can pick a healthier action based on what you've actually been doing. Selection is rule-driven (no ML, no tracking sent anywhere) and runs entirely on your Mac.")
            .font(.system(size: 13))
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func ruleRow(_ rule: Rule, accent: Color) -> some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 7)
                    .fill(accent.opacity(0.12))
                    .frame(width: 36, height: 36)
                Image(systemName: rule.suggestion.iconName)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(accent)
                    .symbolRenderingMode(.hierarchical)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(rule.suggestion.title)
                    .font(.system(size: 13, weight: .semibold))
                Text(rule.trigger)
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 9)
                .fill(Color.secondary.opacity(0.06))
        )
    }

    private var footer: some View {
        Text("Highest-priority rule wins; the same suggestion never shows twice in a row. Suggestion breaks last 25s instead of 20s so you can read the prompt. Turn the whole feature off above to always show the default.")
            .font(.system(size: 11.5))
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, 2)
    }

    private func footerBar(accent: Color) -> some View {
        HStack {
            Spacer()
            Button {
                onClose()
            } label: {
                Text("Done")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 7)
                    .background(accent)
                    .clipShape(RoundedRectangle(cornerRadius: 7))
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.defaultAction)
        }
        .padding(14)
    }
}

#Preview("Light - Peach") {
    BreakSuggestionsHelpView(theme: .peach, onClose: {})
}

#Preview("Dark - Midnight") {
    BreakSuggestionsHelpView(theme: .midnight, onClose: {})
        .preferredColorScheme(.dark)
}
