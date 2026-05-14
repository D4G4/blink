import SwiftUI

/// Onboarding page 2: explains flow detection and lets user adjust sensitivity.
struct FlowSensitivityPage: View {
    let theme: BlinkTheme
    @Binding var sensitivity: Double
    let onLearnMore: () -> Void
    let onGetStarted: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let fg = theme.onBackgroundText(for: colorScheme)
        let accent = theme.accent(for: colorScheme)

        ZStack {
            theme.backgroundGradient(for: colorScheme)
                .ignoresSafeArea()

            VStack(alignment: .center, spacing: 0) {
                Spacer()

                Image(systemName: "brain.head.profile")
                    .font(.system(size: 60, weight: .light))
                    .foregroundStyle(fg.opacity(0.7))
                    .padding(.bottom, 16)

                Text("Flow Detection")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(fg)
                    .padding(.bottom, 6)

                Text("Blink detects when you're focused and extends break intervals")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(fg.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 24)

                FlowSensitivityView(
                    sensitivity: $sensitivity,
                    accentColor: accent,
                    foregroundColor: fg,
                    style: .onboarding
                )

                Spacer()

                VStack(spacing: 30) {
                    Button {
                        onLearnMore()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "info.circle")
                                .font(.system(size: 13))
                            Text("Learn more about flow detection")
                                .font(.system(size: 13, weight: .medium))
                        }
                        .foregroundStyle(fg.opacity(0.7))
                    }
                    .buttonStyle(.plain)

                    Button {
                        onGetStarted()
                    } label: {
                        Text("Get Started")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(theme.backgroundTop(for: colorScheme))
                            .frame(width: 200, height: 48)
                            .background(fg)
                            .clipShape(Capsule())
                            .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 40)
        }
    }

    private func explainerRow(icon: String, text: String, fg: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(theme.backgroundTop(for: colorScheme))
                .frame(width: 36, height: 36)
                .background(fg)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            Text(text)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(fg.opacity(0.9))
            Spacer()
        }
        .padding(12)
        .background(fg.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

#Preview("Flow Sensitivity — Peach") {
    FlowSensitivityPage(
        theme: .peach,
        sensitivity: .constant(0.7),
        onLearnMore: {},
        onGetStarted: {}
    )
    .frame(width: 800, height: 600)
}

#Preview("Flow Sensitivity — Sage") {
    FlowSensitivityPage(
        theme: .sage,
        sensitivity: .constant(0.5),
        onLearnMore: {},
        onGetStarted: {}
    )
    .frame(width: 800, height: 600)
}

#Preview("Flow Sensitivity — Midnight") {
    FlowSensitivityPage(
        theme: .midnight,
        sensitivity: .constant(0.9),
        onLearnMore: {},
        onGetStarted: {}
    )
    .frame(width: 800, height: 600)
    .preferredColorScheme(.dark)
}
