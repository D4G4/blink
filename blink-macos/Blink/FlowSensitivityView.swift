import SwiftUI
import AppKit

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

        var value: Double {
            switch self {
            case .eyeHealth: return 0.45
            case .balanced: return 0.65
            case .deepWork: return 0.85
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
        VStack(spacing: 30) {
            Text("Flow Sensitivity")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(foregroundColor)

            // Three preset cards
            HStack(spacing: 10) {
                ForEach(Preset.allCases, id: \.name) { preset in
                    presetCard(preset, themed: true)
                }
            }

            // Description of selected — fixed height to prevent layout shift
            Text(description)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(foregroundColor)
                .multilineTextAlignment(.center)
                .frame(height: 36, alignment: .top)
                .animation(.easeInOut(duration: 0.2), value: sensitivity)


            Button {
                onResearchTapped?()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "book.closed")
                        .font(.system(size: 10))
                    Text("Read the research")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundStyle(foregroundColor.opacity(0.7))
            }
            .buttonStyle(.plain)
            
        }
        .frame(maxWidth: 560)
    }

    // MARK: - Settings Style

    private var settingsLayout: some View {
        VStack(alignment: .leading, spacing: 30) {
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

            // Learn more button
            if onLearnMoreTapped != nil {
                Button {
                    onLearnMoreTapped?()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "eye")
                            .font(.system(size: 12))
                        Text("How this affects your breaks")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundStyle(accentColor)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(accentColor.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }

            // Action links
            HStack(spacing: 12) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { showFineTune.toggle() }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: showFineTune ? "chevron.up" : "slider.horizontal.3")
                            .font(.system(size: 10))
                        Text(showFineTune ? "Hide" : "Fine-tune")
                            .font(.system(size: 11))
                    }
                    .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)

                Spacer()

                Button {
                    onResearchTapped?()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "book.closed")
                            .font(.system(size: 10))
                        Text("Research")
                            .font(.system(size: 11))
                    }
                    .foregroundStyle(accentColor)
                }
                .buttonStyle(.plain)
            }

            if showFineTune {
                HStack(spacing: 8) {
                    Slider(value: $sensitivity, in: 0.4...0.9, step: 0.05)
                        .tint(accentColor)
                    Text(String(format: "%.0f%%", sensitivity * 100))
                        .font(.system(size: 12, design: .monospaced))
                        .frame(width: 35)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
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
            VStack(spacing: 8) {
                Image(systemName: preset.icon)
                    .font(.system(size: 28, weight: .light))
                Text(preset.name)
                    .font(.system(size: 13, weight: .bold))
                Text(preset.shortDescription)
                    .font(.system(size: 10))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .opacity(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .padding(.horizontal, 8)
            .background(
                themed
                    ? (isSelected ? .white : .white.opacity(0.12))
                    : (isSelected ? accentColor.opacity(0.15) : Color.primary.opacity(0.04))
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .scaleEffect(isSelected ? 1.05 : 1.0)
            .shadow(color: isSelected ? .black.opacity(0.2) : .clear, radius: 10, y: 5)
            .foregroundStyle(
                themed
                    ? (isSelected ? accentColor : .white)
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
