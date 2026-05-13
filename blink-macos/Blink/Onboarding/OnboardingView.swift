import SwiftUI

struct OnboardingView: View {
    @ObservedObject var themeManager: ThemeManager
    let onComplete: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedIndex: Int = 0
    @State private var iconScale: CGFloat = 0.5
    @State private var iconOpacity: Double = 0
    @State private var showWhySheet: Bool = false
    @State private var showFlowPage: Bool = false
    @AppStorage("flowSensitivity") private var flowSensitivity: Double = 0.7

    private let themes: [BlinkTheme]

    init(themeManager: ThemeManager, isDarkMode: Bool = false, onComplete: @escaping () -> Void) {
        self.themeManager = themeManager
        self.onComplete = onComplete
        self.themes = isDarkMode ? BlinkTheme.allDark : BlinkTheme.allLight
    }

    private var selectedTheme: BlinkTheme {
        themes[max(0, min(selectedIndex, themes.count - 1))]
    }

    var body: some View {
        ZStack {
            selectedTheme.backgroundGradient(for: colorScheme)
                .animation(.easeInOut(duration: 0.5), value: selectedIndex)
                .animation(.easeInOut(duration: 0.3), value: colorScheme)
                .ignoresSafeArea()

            RadialGradient(
                colors: [selectedTheme.onBackgroundText(for: colorScheme).opacity(0.1), .clear],
                center: .center,
                startRadius: 50,
                endRadius: 300
            )

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 8) {
                    Text("Welcome to Blink")
                        .font(.system(size: 38, weight: .bold, design: .rounded))
                        .foregroundStyle(selectedTheme.onBackgroundText(for: colorScheme))

                    Text("Smart breaks for your eyes")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(selectedTheme.onBackgroundText(for: colorScheme).opacity(0.7))
                }
                .padding(.bottom, 48)

                Image(selectedTheme.iconAsset)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 200, height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 40, style: .continuous))
                    .shadow(color: .black.opacity(0.25), radius: 24, y: 10)
                    .scaleEffect(iconScale)
                    .opacity(iconOpacity)
                    .animation(.spring(response: 0.5, dampingFraction: 0.7), value: selectedIndex)
                    .id(selectedIndex)
                    .frame(height: 220)

                Text(selectedTheme.name)
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .foregroundStyle(selectedTheme.onBackgroundText(for: colorScheme))
                    .padding(.top, 24)
                    .animation(.easeInOut(duration: 0.3), value: selectedIndex)

                // Navigation arrows
                HStack(spacing: 60) {
                    Button {
                        withAnimation { navigatePrevious() }
                    } label: {
                        Image(systemName: "chevron.left.circle.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(selectedTheme.onBackgroundText(for: colorScheme).opacity(selectedIndex > 0 ? 0.8 : 0.2))
                    }
                    .buttonStyle(.plain)
                    .disabled(selectedIndex == 0)

                    HStack(spacing: 8) {
                        ForEach(0..<themes.count, id: \.self) { i in
                            Circle()
                                .fill(selectedTheme.onBackgroundText(for: colorScheme).opacity(i == selectedIndex ? 1.0 : 0.3))
                                .frame(width: i == selectedIndex ? 10 : 7,
                                       height: i == selectedIndex ? 10 : 7)
                                .animation(.easeOut(duration: 0.2), value: selectedIndex)
                        }
                    }

                    Button {
                        withAnimation { navigateNext() }
                    } label: {
                        Image(systemName: "chevron.right.circle.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(selectedTheme.onBackgroundText(for: colorScheme).opacity(selectedIndex < themes.count - 1 ? 0.8 : 0.2))
                    }
                    .buttonStyle(.plain)
                    .disabled(selectedIndex == themes.count - 1)
                }
                .padding(.top, 36)

                Spacer()

                // Why do I exist — above Get Started
                Button {
                    withAnimation(.spring(response: 0.4)) { showWhySheet = true }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "questionmark.circle")
                            .font(.system(size: 15))
                        Text("Why do I exist?")
                            .font(.system(size: 15, weight: .medium))
                    }
                    .foregroundStyle(selectedTheme.onBackgroundText(for: colorScheme))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(selectedTheme.onBackgroundText(for: colorScheme).opacity(0.15))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .padding(.bottom, 12)

                // Next / Get Started button
                Button {
                    themeManager.select(selectedTheme)
                    if !showFlowPage {
                        withAnimation(.easeInOut(duration: 0.4)) { showFlowPage = true }
                    } else {
                        themeManager.hasCompletedOnboarding = true
                        onComplete()
                    }
                } label: {
                    Text(showFlowPage ? "Get Started" : "Next")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(selectedTheme.backgroundTop(for: colorScheme))
                        .frame(width: 200, height: 48)
                        .background(selectedTheme.onBackgroundText(for: colorScheme))
                        .clipShape(Capsule())
                        .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
                }
                .buttonStyle(.plain)
                .padding(.bottom, 32)
            }

            // Flow sensitivity page overlay
            if showFlowPage {
                flowSensitivityPage
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }

            if showWhySheet {
                ZStack {
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .ignoresSafeArea()
                        .onTapGesture { withAnimation(.spring(response: 0.3)) { showWhySheet = false } }

                    WhyExistView(theme: selectedTheme, onDismiss: {
                        withAnimation(.spring(response: 0.3)) { showWhySheet = false }
                    })
                    .frame(width: 620, height: 560)
                    .background(Color(nsColor: .windowBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .shadow(color: .black.opacity(0.3), radius: 30, y: 10)
                }
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                iconScale = 1.0
                iconOpacity = 1.0
            }
        }
        .onKeyPress(.leftArrow) {
            withAnimation { navigatePrevious() }
            return .handled
        }
        .onKeyPress(.rightArrow) {
            withAnimation { navigateNext() }
            return .handled
        }
        .onKeyPress(.return) {
            themeManager.select(selectedTheme)
            themeManager.hasCompletedOnboarding = true
            onComplete()
            return .handled
        }
    }

    // MARK: - Flow Sensitivity Page

    private var flowSensitivityPage: some View {
        let fg = selectedTheme.onBackgroundText(for: colorScheme)
        let accent = selectedTheme.accent(for: colorScheme)

        return ZStack {
            selectedTheme.backgroundGradient(for: colorScheme)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                Image(systemName: "brain.head.profile")
                    .font(.system(size: 48, weight: .light))
                    .foregroundStyle(accent)
                    .padding(.bottom, 20)

                Text("Flow Detection")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(fg)
                    .padding(.bottom, 8)

                Text("Blink detects when you're focused and extends break intervals")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(fg.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 32)

                // What is flow?
                VStack(alignment: .leading, spacing: 12) {
                    flowExplainerRow(
                        icon: "keyboard",
                        text: "Steady typing rhythm = focused work",
                        fg: fg, accent: accent
                    )
                    flowExplainerRow(
                        icon: "arrow.triangle.swap",
                        text: "Fewer app switches = deeper concentration",
                        fg: fg, accent: accent
                    )
                    flowExplainerRow(
                        icon: "timer",
                        text: "In flow: 20 min → 30 min. Deep flow: → 40 min",
                        fg: fg, accent: accent
                    )
                }
                .frame(maxWidth: 380)
                .padding(.bottom, 32)

                // Sensitivity slider
                VStack(spacing: 12) {
                    Text("Flow Sensitivity")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(fg)

                    HStack(spacing: 12) {
                        Text("Low")
                            .font(.system(size: 12))
                            .foregroundStyle(fg.opacity(0.6))
                        Slider(value: $flowSensitivity, in: 0.4...0.9, step: 0.05)
                            .tint(accent)
                        Text("High")
                            .font(.system(size: 12))
                            .foregroundStyle(fg.opacity(0.6))
                    }

                    Text(String(format: "%.0f%%", flowSensitivity * 100))
                        .font(.system(size: 28, weight: .light, design: .monospaced))
                        .foregroundStyle(fg)

                    Text("Higher = flow detected more easily, longer intervals between breaks")
                        .font(.system(size: 12))
                        .foregroundStyle(fg.opacity(0.6))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: 340)
                .padding(24)
                .background(fg.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 16))

                Spacer()

                // Back button
                Button {
                    withAnimation(.easeInOut(duration: 0.4)) { showFlowPage = false }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 13))
                        Text("Back to themes")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundStyle(fg.opacity(0.7))
                }
                .buttonStyle(.plain)
                .padding(.bottom, 12)

                // Get Started button
                Button {
                    themeManager.hasCompletedOnboarding = true
                    onComplete()
                } label: {
                    Text("Get Started")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(selectedTheme.backgroundTop(for: colorScheme))
                        .frame(width: 200, height: 48)
                        .background(fg)
                        .clipShape(Capsule())
                        .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
                }
                .buttonStyle(.plain)
                .padding(.bottom, 32)
            }
            .padding(.horizontal, 40)
        }
    }

    private func flowExplainerRow(icon: String, text: String, fg: Color, accent: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(selectedTheme.backgroundTop(for: colorScheme))
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

    private func navigatePrevious() {
        guard selectedIndex > 0 else { return }
        iconScale = 0.8
        iconOpacity = 0.5
        selectedIndex -= 1
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            iconScale = 1.0
            iconOpacity = 1.0
        }
    }

    private func navigateNext() {
        guard selectedIndex < themes.count - 1 else { return }
        iconScale = 0.8
        iconOpacity = 0.5
        selectedIndex += 1
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            iconScale = 1.0
            iconOpacity = 1.0
        }
    }
}

#Preview("Onboarding") {
    OnboardingView(themeManager: ThemeManager.shared, onComplete: {})
        .frame(width: 900, height: 650)
}
