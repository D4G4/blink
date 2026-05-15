import SwiftUI
import AppKit

/// Reusable flow sensitivity slider with dynamic description.
/// Used in onboarding and Settings.
struct FlowSensitivityView: View {
    @Binding var sensitivity: Double
    let accentColor: Color
    let foregroundColor: Color
    let style: Style

    enum Style {
        /// Onboarding: themed background, larger text
        case onboarding
        /// Settings: compact, system colors
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

    // MARK: - Onboarding Style

    private var onboardingLayout: some View {
        VStack(spacing: 10) {
            Text("Flow Sensitivity")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(foregroundColor)

            HStack(spacing: 12) {
                Text("Low")
                    .font(.system(size: 12))
                    .foregroundStyle(foregroundColor)
                Slider(value: $sensitivity, in: 0.4...0.9, step: 0.05)
                    .tint(accentColor)
                Text("High")
                    .font(.system(size: 12))
                    .foregroundStyle(foregroundColor)
            }

            Text(String(format: "%.0f%%", sensitivity * 100))
                .font(.system(size: 24, weight: .light, design: .monospaced))
                .foregroundStyle(foregroundColor)

            Text(description)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(foregroundColor)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(minHeight: 32, alignment: .top)
                .animation(.easeInOut(duration: 0.2), value: sensitivity)

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
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Slider(value: $sensitivity, in: 0.4...0.9, step: 0.05)
                    .tint(accentColor)
                Text(String(format: "%.0f%%", sensitivity * 100))
                    .font(.system(size: 13, design: .monospaced))
                    .frame(width: 40)
            }

            Text(description)
                .font(.system(size: 11))
                .foregroundStyle(researchWarningLevel == .caution ? .orange : .secondary)
                .animation(.easeInOut(duration: 0.2), value: sensitivity)

            if researchWarningLevel == .caution {
                Button {
                    ResearchWindowController.shared.show(theme: BlinkTheme.named(UserDefaults.standard.string(forKey: "selectedTheme") ?? "peach"))
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "book.closed")
                            .font(.system(size: 10))
                        Text("Read the research")
                            .font(.system(size: 11))
                    }
                    .foregroundStyle(.orange)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Description

    private var gapSeconds: Int {
        let t = (sensitivity - 0.4) / (0.9 - 0.4)
        return Int(15 + t * 75)
    }

    var description: String {
        switch sensitivity {
        case ..<0.5:
            return "Strict — Blink prioritizes your eye health. Breaks come at 20 min unless your work rhythm is very intense."
        case 0.5..<0.6:
            return "Conservative — only sustained, focused work extends your timer. Casual browsing gets regular breaks."
        case 0.6..<0.7:
            return "Balanced — Blink recognizes most focused work and extends your timer. Light use gets breaks at 20 min."
        case 0.7..<0.8:
            return "Recommended — Blink learns your work rhythm and extends when you're focused. Your blink rate drops 69% during deep work."
        case 0.8..<0.9:
            return "Relaxed — Blink extends your timer easily. ⚠️ Your eyes strain most during the focused work you're protecting."
        default:
            return "Very relaxed — almost any activity extends your timer. ⚠️ Research shows your blink rate drops to 5/min during focus."
        }
    }

    var researchWarningLevel: ResearchWarningLevel {
        switch sensitivity {
        case ..<0.6: return .safe
        case 0.6..<0.8: return .neutral
        default: return .caution
        }
    }

    enum ResearchWarningLevel {
        case safe, neutral, caution
    }
}

// MARK: - Previews

private struct FlowSensitivityPreview: View {
    @State private var sensitivity: Double
    let style: FlowSensitivityView.Style

    init(sensitivity: Double = 0.7, style: FlowSensitivityView.Style = .onboarding) {
        self._sensitivity = State(initialValue: sensitivity)
        self.style = style
    }

    var body: some View {
        FlowSensitivityView(
            sensitivity: $sensitivity,
            accentColor: BlinkTheme.peach.accent,
            foregroundColor: .white,
            style: style
        )
    }
}

#Preview("Onboarding Style") {
    FlowSensitivityPreview(style: .onboarding)
        .padding(40)
        .frame(width: 500, height: 300)
        .background(BlinkTheme.peach.backgroundGradient)
}

#Preview("Settings Style") {
    FlowSensitivityPreview(sensitivity: 0.5, style: .settings)
        .padding(20)
        .frame(width: 440, height: 200)
}
