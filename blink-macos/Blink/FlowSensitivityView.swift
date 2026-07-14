import SwiftUI
import AppKit
import BlinkCore

/// Three-option flow sensitivity picker with optional fine-tune slider.
/// Used in onboarding and Settings.
struct FlowSensitivityView: View {
    @Binding var sensitivity: Double
    let accentColor: Color
    let foregroundColor: Color
    let style: Style
    var onResearchTapped: (() -> Void)? = nil
    var onLearnMoreTapped: (() -> Void)? = nil

    @State private var showFineTune = false

    enum Style {
        case onboarding
        case settings
    }

    var body: some View {
        switch style {
        case .onboarding:
            onboardingLayout
        case .settings:
            settingsLayout
        }
    }

    // MARK: - Presets

    enum Preset: CaseIterable {
        case eyeHealth, balanced, deepWork

        // Sensitivity → threshold mapping is `threshold = 1.1 - sensitivity`
        // (see BlinkCore/BreakDecisionEngine.swift). The values below pick a
        // meaningful spread across the three presets:
        //   Eye health (0.30 → threshold 0.80): very hard to extend — break-heavy
        //   Balanced   (0.50 → threshold 0.60): moderate — needs real flow signal
        //   Deep work  (0.75 → threshold 0.35): extends readily when focused
        //
        // `balanced` IS the canonical default — the single source of
        // truth for what a fresh user gets. BlinkCore has no internal
        // default of its own; AppState reads this when constructing the
        // engine, and @AppStorage falls back to this when the key is
        // missing. Change this number and the entire app moves with it.
        var value: Double {
            switch self {
            case .eyeHealth: return 0.30
            case .balanced: return 0.50
            case .deepWork: return 0.75
            }
        }

        var icon: String {
            switch self {
            case .eyeHealth: return "heart.circle.fill"
            case .balanced: return "scale.3d"
            case .deepWork: return "brain.head.profile"
            }
        }

        var name: String {
            switch self {
            case .eyeHealth: return "Eye health"
            case .balanced: return "Balanced"
            case .deepWork: return "Deep work"
            }
        }

        var shortDescription: String {
            switch self {
            case .eyeHealth: return "Regular breaks. Only intense work extends."
            case .balanced: return "Smart timing. Extends for focused work."
            case .deepWork: return "Fewer interruptions. Gentle reminders."
            }
        }

        static func closest(to value: Double) -> Preset {
            allCases.min(by: { abs($0.value - value) < abs($1.value - value) }) ?? .balanced
        }
    }

    private var selectedPreset: Preset {
        Preset.closest(to: sensitivity)
    }

    // MARK: - Onboarding Style

    private var onboardingLayout: some View {
        VStack(spacing: 28) {
            
            // Three preset cards
            HStack(spacing: 14) {
                ForEach(Preset.allCases, id: \.name) { preset in
                    presetCard(preset, themed: true)
                }
            }

            // Description of selected — fixed height to prevent layout shift
            Text(description)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(foregroundColor)
                .multilineTextAlignment(.center)
                .frame(height: 40, alignment: .top)
                .animation(.easeInOut(duration: 0.2), value: sensitivity)
        }
        .frame(maxWidth: 600)
    }

    // MARK: - Settings Style

    private var settingsLayout: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Full-width preset buttons
            HStack(spacing: 8) {
                ForEach(Preset.allCases, id: \.name) { preset in
                    settingsPresetButton(preset)
                }
            }

            // Description
            Text(description)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .animation(.easeInOut(duration: 0.2), value: sensitivity)

            // Compact link row — Fine-tune · How it works · Research. Replaces
            // the old full-width "How this affects your breaks" button so the
            // settings pane reads lighter.
            HStack(spacing: 14) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { showFineTune.toggle() }
                } label: {
                    inlineLink(showFineTune ? "chevron.up" : "slider.horizontal.3",
                               showFineTune ? "Hide" : "Fine-tune",
                               color: .secondary)
                }
                .buttonStyle(.plain)

                if onLearnMoreTapped != nil {
                    Button { onLearnMoreTapped?() } label: {
                        inlineLink("eye", "How it works", color: accentColor)
                    }
                    .buttonStyle(.plain)
                }

                Spacer()

                Button { onResearchTapped?() } label: {
                    inlineLink("book.closed", "Research", color: accentColor)
                }
                .buttonStyle(.plain)
            }

            if showFineTune {
                HStack(spacing: 8) {
                    // Range covers all three preset values (Eye health
                    // 0.30 → Deep work 0.75) plus a little headroom on
                    // each end for fine-tuning.
                    Slider(value: $sensitivity, in: 0.25...0.90, step: 0.05)
                        .tint(accentColor)
                    Text(String(format: "%.0f%%", sensitivity * 100))
                        .font(.system(size: 12, design: .monospaced))
                        .frame(width: 35)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    // Small labelled link used in the settings action row.
    private func inlineLink(_ symbol: String, _ label: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: symbol)
                .font(.system(size: 10))
            Text(label)
                .font(.system(size: 11))
        }
        .foregroundStyle(color)
    }

    // Compact settings preset button — icon + name, no description
    private func settingsPresetButton(_ preset: Preset) -> some View {
        let isSelected = selectedPreset == preset

        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                sensitivity = preset.value
            }
        } label: {
            VStack(spacing: 6) {
                Image(systemName: preset.icon)
                    .font(.system(size: 22, weight: .light))
                Text(preset.name)
                    .font(.system(size: 12, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(isSelected ? accentColor.opacity(0.12) : Color.primary.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12).stroke(isSelected ? accentColor : .clear, lineWidth: 1.5)
            )
            .scaleEffect(isSelected ? 1.03 : 1.0)
            .foregroundStyle(isSelected ? accentColor : .primary)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Preset Card

    private func presetCard(_ preset: Preset, themed: Bool) -> some View {
        let isSelected = selectedPreset == preset

        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                sensitivity = preset.value
            }
        } label: {
            VStack(spacing: 10) {
                Image(systemName: preset.icon)
                    .font(.system(size: 32, weight: .light))
                Text(preset.name)
                    .font(.system(size: 15, weight: .bold))
                Text(preset.shortDescription)
                    .font(.system(size: 12))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .opacity(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .padding(.horizontal, 10)
            .background(
                themed
                    ? (isSelected ? .white : foregroundColor.opacity(0.12))
                    : (isSelected ? accentColor.opacity(0.15) : Color.primary.opacity(0.04))
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .scaleEffect(isSelected ? 1.05 : 1.0)
            .shadow(color: isSelected ? .black.opacity(0.2) : .clear, radius: 10, y: 5)
            .foregroundStyle(
                themed
                    ? (isSelected ? accentColor : foregroundColor)
                    : (isSelected ? accentColor : .primary)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Description

    var description: String {
        switch Preset.closest(to: sensitivity) {
        case .eyeHealth:
            return "Blink prioritizes your eye health.\nBreaks come at 20 min unless your work rhythm is very intense."
        case .balanced:
            return "Blink learns your work rhythm and extends when you're truly focused.\nRecommended for most users."
        case .deepWork:
            return "Fewer interruptions during focus. Blink reminds you gently.\nBest if you're disciplined about breaks."
        }
    }

    var researchWarningLevel: ResearchWarningLevel {
        switch Preset.closest(to: sensitivity) {
        case .eyeHealth: return .safe
        case .balanced: return .neutral
        case .deepWork: return .caution
        }
    }

    enum ResearchWarningLevel {
        case safe, neutral, caution
    }
}

// MARK: - Previews

private struct FlowSensitivityPreview: View {
    @State private var sensitivity: Double

    init(sensitivity: Double = 0.65) {
        self._sensitivity = State(initialValue: sensitivity)
    }

    var body: some View {
        FlowSensitivityView(
            sensitivity: $sensitivity,
            accentColor: BlinkTheme.peach.accent,
            foregroundColor: .white,
            style: .onboarding
        )
    }
}

#Preview("Onboarding") {
    FlowSensitivityPreview()
        .padding(40)
        .background(BlinkTheme.peach.backgroundGradient)
}

#Preview("Settings") {
    FlowSensitivityView(
        sensitivity: .constant(0.65),
        accentColor: BlinkTheme.peach.accent,
        foregroundColor: .primary,
        style: .settings,
        onResearchTapped: {},
        onLearnMoreTapped: {}
    )
    .padding(20)
    .frame(width: 400)
}
