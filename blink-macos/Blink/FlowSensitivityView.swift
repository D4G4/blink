import SwiftUI
import AppKit

/// Three-option flow sensitivity picker with optional fine-tune slider.
/// Used in onboarding and Settings.
struct FlowSensitivityView: View {
    @Binding var sensitivity: Double
    let accentColor: Color
    let foregroundColor: Color
    let style: Style

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
        VStack(spacing: 14) {
            Text("Flow Sensitivity")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(foregroundColor)

            // Three preset cards
            HStack(spacing: 10) {
                ForEach(Preset.allCases, id: \.name) { preset in
                    presetCard(preset, themed: true)
                }
            }

            // Description of selected
            Text(description)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(foregroundColor)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(minHeight: 32, alignment: .top)
                .animation(.easeInOut(duration: 0.2), value: sensitivity)

            // Fine-tune expander
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { showFineTune.toggle() }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: showFineTune ? "chevron.up" : "slider.horizontal.3")
                        .font(.system(size: 10))
                    Text(showFineTune ? "Hide" : "Fine-tune")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundStyle(foregroundColor.opacity(0.6))
            }
            .buttonStyle(.plain)

            if showFineTune {
                HStack(spacing: 8) {
                    Slider(value: $sensitivity, in: 0.4...0.9, step: 0.05)
                        .tint(accentColor)
                    Text(String(format: "%.0f%%", sensitivity * 100))
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(foregroundColor)
                        .frame(width: 35)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            if researchWarningLevel == .caution {
                Button {
                    ResearchWindowController.shared.show(theme: BlinkTheme.named(UserDefaults.standard.string(forKey: "selectedTheme") ?? "peach"))
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
        }
        .frame(maxWidth: 420)
        .padding(20)
        .background(foregroundColor.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Settings Style

    private var settingsLayout: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Three preset buttons
            HStack(spacing: 8) {
                ForEach(Preset.allCases, id: \.name) { preset in
                    presetCard(preset, themed: false)
                }
            }

            // Description
            Text(description)
                .font(.system(size: 11))
                .foregroundStyle(.primary)
                .animation(.easeInOut(duration: 0.2), value: sensitivity)

            // Fine-tune + research
            HStack {
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
                    ResearchWindowController.shared.show(theme: BlinkTheme.named(UserDefaults.standard.string(forKey: "selectedTheme") ?? "peach"))
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "book.closed")
                            .font(.system(size: 10))
                        Text("Read the research")
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

    // MARK: - Preset Card

    private func presetCard(_ preset: Preset, themed: Bool) -> some View {
        let isSelected = selectedPreset == preset

        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                sensitivity = preset.value
            }
        } label: {
            VStack(spacing: 6) {
                Image(systemName: preset.icon)
                    .font(.system(size: 18))
                Text(preset.name)
                    .font(.system(size: 11, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                themed
                    ? (isSelected ? foregroundColor.opacity(0.2) : foregroundColor.opacity(0.08))
                    : (isSelected ? accentColor.opacity(0.15) : Color.primary.opacity(0.04))
            )
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(
                        isSelected
                            ? (themed ? foregroundColor.opacity(0.5) : accentColor)
                            : Color.clear,
                        lineWidth: 1.5
                    )
            )
            .foregroundStyle(themed ? foregroundColor : .primary)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Description

    var description: String {
        switch Preset.closest(to: sensitivity) {
        case .eyeHealth:
            return "Blink prioritizes your eye health. Breaks come at 20 min unless your work rhythm is very intense."
        case .balanced:
            return "Blink learns your work rhythm and extends when you're truly focused. Recommended for most users."
        case .deepWork:
            return "Fewer interruptions during focus. Blink reminds you gently. Best if you're disciplined about breaks."
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
        .frame(width: 500, height: 350)
        .background(BlinkTheme.peach.backgroundGradient)
}

#Preview("Settings") {
    FlowSensitivityPreview(sensitivity: 0.65)
        .padding(20)
        .frame(width: 440, height: 250)
        .environment(\.colorScheme, .light)
}
