import SwiftUI

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
                    .foregroundStyle(foregroundColor.opacity(0.7))
                Slider(value: $sensitivity, in: 0.4...0.9, step: 0.05)
                    .tint(accentColor)
                Text("High")
                    .font(.system(size: 12))
                    .foregroundStyle(foregroundColor.opacity(0.7))
            }

            Text(String(format: "%.0f%%", sensitivity * 100))
                .font(.system(size: 24, weight: .light, design: .monospaced))
                .foregroundStyle(foregroundColor)

            Text(description)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(foregroundColor.opacity(0.8))
                .multilineTextAlignment(.center)
                .animation(.easeInOut(duration: 0.2), value: sensitivity)
        }
        .frame(maxWidth: 320)
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
                .foregroundStyle(.secondary)
                .animation(.easeInOut(duration: 0.2), value: sensitivity)
        }
    }

    // MARK: - Description

    var description: String {
        switch sensitivity {
        case ..<0.5:
            return "Strict — flow rarely detected. Breaks every 20 min even during focus."
        case 0.5..<0.6:
            return "Conservative — only intense coding sessions trigger flow. Breaks mostly at 20 min."
        case 0.6..<0.7:
            return "Balanced — steady work extends to 30 min. Casual browsing stays at 20 min."
        case 0.7..<0.8:
            return "Recommended — normal work extends to 30 min. Deep focus reaches 40 min."
        case 0.8..<0.9:
            return "Sensitive — most focused work triggers flow. Breaks at 30–40 min."
        default:
            return "Very sensitive — flow detected easily. You'll rarely get a break at 20 min."
        }
    }
}
