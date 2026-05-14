import SwiftUI

/// Onboarding page 1: theme selection carousel.
/// After selecting a theme, transitions to FlowSensitivityPage.
struct OnboardingView: View {
    @ObservedObject var themeManager: ThemeManager
    let onComplete: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedIndex: Int = 0
    @State private var iconScale: CGFloat = 0.5
    @State private var iconOpacity: Double = 0
    @State private var showWhySheet: Bool = false
    @State private var showFlowPage: Bool = false
    @State private var showFlowLearnMore: Bool = false
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
            themeSelectionPage

            if showFlowPage {
                FlowSensitivityPage(
                    theme: selectedTheme,
                    sensitivity: $flowSensitivity,
                    onBack: { withAnimation(.easeInOut(duration: 0.4)) { showFlowPage = false } },
                    onLearnMore: { withAnimation(.spring(response: 0.4)) { showFlowLearnMore = true } },
                    onGetStarted: {
                        themeManager.hasCompletedOnboarding = true
                        onComplete()
                    }
                )
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }

            if showWhySheet {
                sheetOverlay {
                    WhyExistView(theme: selectedTheme, onDismiss: {
                        withAnimation(.spring(response: 0.3)) { showWhySheet = false }
                    })
                    .frame(width: 620, height: 560)
                } onDismiss: {
                    showWhySheet = false
                }
            }

            if showFlowLearnMore {
                sheetOverlay {
                    FlowLearnMoreView(theme: selectedTheme, onDismiss: {
                        withAnimation(.spring(response: 0.3)) { showFlowLearnMore = false }
                    })
                    .frame(width: 480, height: 560)
                } onDismiss: {
                    showFlowLearnMore = false
                }
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

    // MARK: - Theme Selection Page

    private var themeSelectionPage: some View {
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

                // Title
                VStack(spacing: 8) {
                    Text("Welcome to Blink")
                        .font(.system(size: 38, weight: .bold, design: .rounded))
                        .foregroundStyle(selectedTheme.onBackgroundText(for: colorScheme))

                    Text("Smart breaks for your eyes")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(selectedTheme.onBackgroundText(for: colorScheme).opacity(0.7))
                }
                .padding(.bottom, 48)

                // Theme icon
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

                // Navigation arrows + dots
                themeNavigationControls
                    .padding(.top, 36)

                Spacer()

                // Why do I exist?
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

                // Next button
                Button {
                    themeManager.select(selectedTheme)
                    withAnimation(.easeInOut(duration: 0.4)) { showFlowPage = true }
                } label: {
                    Text("Next")
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
        }
    }

    // MARK: - Theme Navigation

    private var themeNavigationControls: some View {
        let fg = selectedTheme.onBackgroundText(for: colorScheme)
        return HStack(spacing: 60) {
            Button {
                withAnimation { navigatePrevious() }
            } label: {
                Image(systemName: "chevron.left.circle.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(fg.opacity(selectedIndex > 0 ? 0.8 : 0.2))
            }
            .buttonStyle(.plain)
            .disabled(selectedIndex == 0)

            HStack(spacing: 8) {
                ForEach(0..<themes.count, id: \.self) { i in
                    Circle()
                        .fill(fg.opacity(i == selectedIndex ? 1.0 : 0.3))
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
                    .foregroundStyle(fg.opacity(selectedIndex < themes.count - 1 ? 0.8 : 0.2))
            }
            .buttonStyle(.plain)
            .disabled(selectedIndex == themes.count - 1)
        }
    }

    // MARK: - Sheet Overlay

    private func sheetOverlay<Content: View>(
        @ViewBuilder content: () -> Content,
        onDismiss: @escaping () -> Void
    ) -> some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
                .onTapGesture { withAnimation(.spring(response: 0.3)) { onDismiss() } }

            content()
                .background(Color(nsColor: .windowBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .shadow(color: .black.opacity(0.3), radius: 30, y: 10)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
    }

    // MARK: - Navigation

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
