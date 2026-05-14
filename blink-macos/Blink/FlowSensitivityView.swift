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
                Slider(value: $sensitivity, in: 0.4...0.9, step: 0.05)
                    .tint(accentColor)
                Text("High")
                    .font(.system(size: 12))
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
                .foregroundStyle(.secondary)
                .animation(.easeInOut(duration: 0.2), value: sensitivity)
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
            return "Strict — pauses over \(gapSeconds)s break flow. Only continuous action counts."
        case 0.5..<0.6:
            return "Conservative — pauses up to \(gapSeconds)s keep flow. Short thinking breaks are OK."
        case 0.6..<0.7:
            return "Balanced — pauses up to \(gapSeconds)s keep flow. Brief reading won't interrupt."
        case 0.7..<0.8:
            return "Recommended — pauses up to \(gapSeconds)s keep flow. Natural thinking stays in flow."
        case 0.8..<0.9:
            return "Relaxed — pauses up to \(gapSeconds)s keep flow. Long reading sessions are fine."
        default:
            return "Very relaxed — pauses up to \(gapSeconds)s keep flow. Almost any activity counts."
        }
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
