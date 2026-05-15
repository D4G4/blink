import SwiftUI

/// Onboarding page 2: explains flow detection and lets user adjust sensitivity.
struct FlowSensitivityPage: View {
    let theme: BlinkTheme
    @Binding var sensitivity: Double
    let onBack: () -> Void
    let onLearnMore: () -> Void
    let onGetStarted: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var pulsing = false

    var body: some View {
        let fg = theme.onBackgroundText(for: colorScheme)
        let accent = theme.accent(for: colorScheme)

        ZStack(alignment: .topLeading) {
            theme.backgroundGradient(for: colorScheme)
                .ignoresSafeArea()

            // Back button
            Button {
                onBack()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Themes")
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundStyle(fg.opacity(0.7))
            }
            .buttonStyle(.plain)
            .padding(.top, 20)
            .padding(.leading, 24)

            VStack(spacing: 0) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 60, weight: .light))
                    .foregroundStyle(fg.opacity(0.7))
                    .frame(maxWidth: .infinity)

                Spacer()

                Text("Flow Detection")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(fg)
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 6)

                Text("Blink learns your work rhythm and decides when you truly need a break")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(fg.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 24)

                FlowSensitivityView(
                    sensitivity: $sensitivity,
                    accentColor: accent,
                    foregroundColor: fg,
                    style: .onboarding
                )
                .frame(maxWidth: .infinity)

                Spacer()

                VStack(spacing: 30) {
                    Button {
                        onLearnMore()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "slider.horizontal.3")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Explore how it works")
                                .font(.system(size: 14, weight: .bold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(.white.opacity(0.2))
                        .clipShape(Capsule())
                        .scaleEffect(pulsing ? 1.05 : 1.0)
                        .opacity(pulsing ? 1.0 : 0.85)
                        .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: pulsing)
                        .onAppear { pulsing = true }
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
        onBack: {},
        onLearnMore: {},
        onGetStarted: {}
    )
    .frame(width: 800, height: 600)
}

#Preview("Flow Sensitivity — Sand") {
    FlowSensitivityPage(
        theme: .sand,
        sensitivity: .constant(0.5),
        onBack: {},
        onLearnMore: {},
        onGetStarted: {}
    )
    .frame(width: 800, height: 600)
}

#Preview("Flow Sensitivity — Midnight") {
    FlowSensitivityPage(
        theme: .midnight,
        sensitivity: .constant(0.9),
        onBack: {},
        onLearnMore: {},
        onGetStarted: {}
    )
    .frame(width: 800, height: 600)
    .preferredColorScheme(.dark)
}
