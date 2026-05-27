import SwiftUI

/// Onboarding proper: theme selection → flow sensitivity. The permission
/// flow (mic + IM) is a SEPARATE window — see PermissionFlowView /
/// PermissionFlowWindowController. This split exists so a macOS TCC
/// restart mid-permission-grant doesn't push the user back through
/// theme + flow on relaunch (the relaunch only needs to surface the
/// permission flow).
///
/// `hasCompletedOnboarding` is set to true as soon as the user clicks
/// Get Started on the flow sensitivity page — at that point the user has
/// chosen their setup, and any further interruption (TCC restart,
/// crash, etc.) should NOT replay theme + flow selection.
struct OnboardingView: View {
    @ObservedObject var themeManager: ThemeManager
    /// Called when the user finishes theme + flow sensitivity selection.
    /// AppState decides what to do next (start the engine if permissions
    /// already in place, otherwise show PermissionFlowWindowController).
    let onComplete: () -> Void

    /// Onboarding renders the variant matching the user's system appearance
    /// by default — so a user already in dark mode sees the dark variant
    /// (which is the colors they'll actually live with day-to-day). The
    /// bottom-right toggle lets them preview the other variant on demand.
    @State private var previewDark: Bool
    @State private var selectedIndex: Int = 0
    @State private var iconScale: CGFloat = 0.5
    @State private var iconOpacity: Double = 0
    @State private var showWhySheet: Bool = false
    @State private var showFlowPage: Bool = false
    @State private var showFlowLearnMore: Bool = false
    /// Default = Balanced preset value (see FlowSensitivityView.Preset.balanced).
    /// Picked so users who walk through onboarding without explicitly tapping
    /// a preset still land on the canonical Balanced threshold (0.60).
    @AppStorage("flowSensitivity") private var flowSensitivity: Double = 0.50

    private let themes: [BlinkTheme]

    init(themeManager: ThemeManager, isDarkMode: Bool = false, onComplete: @escaping () -> Void) {
        self.themeManager = themeManager
        self.onComplete = onComplete
        self.themes = BlinkTheme.allLight  // theme ordering — always Peach-first for onboarding
        self._previewDark = State(initialValue: isDarkMode)  // initial variant follows system appearance
    }

    /// The colorScheme passed to theme methods — overridden by the preview toggle
    /// instead of inherited from the system, so onboarding shows actual theme
    /// colors and not the dark-tinted variant by default.
    private var effectiveColorScheme: ColorScheme {
        previewDark ? .dark : .light
    }

    private var selectedTheme: BlinkTheme {
        themes[max(0, min(selectedIndex, themes.count - 1))]
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            themeSelectionPage

            if showFlowPage {
                FlowSensitivityPage(
                    theme: selectedTheme,
                    sensitivity: $flowSensitivity,
                    onBack: { withAnimation(.easeInOut(duration: 0.4)) { showFlowPage = false } },
                    onLearnMore: { withAnimation(.easeInOut(duration: 0.4)) { showFlowLearnMore = true } },
                    onGetStarted: {
                        // Mark onboarding done THE MOMENT the user
                        // commits to their flow sensitivity choice — any
                        // subsequent interruption (TCC restart, crash,
                        // app quit) should not push them back through
                        // theme + flow on relaunch. The permission flow
                        // (mic + IM) is presented separately by AppState
                        // via PermissionFlowWindowController.
                        themeManager.hasCompletedOnboarding = true
                        onComplete()
                    }
                )
                .transition(.opacity)
            }

            // Preview dark/light toggle — overlay so it's always at the
            // window corner regardless of inner content layout. Hidden
            // on the flow sensitivity page (no theme preview to compare
            // there).
            if !showFlowPage {
                darkPreviewToggle
                    .padding(20)
                    .transition(.opacity)
            }
        }
        .sheet(isPresented: $showWhySheet) {
            WhyExistView(theme: selectedTheme, onDismiss: {
                showWhySheet = false
            })
            .frame(width: 620, height: 560)
        }
        .sheet(isPresented: $showFlowLearnMore) {
            FlowLearnMoreView(theme: selectedTheme, onDismiss: {
                showFlowLearnMore = false
            })
            .frame(width: 480, height: 700)
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
            // Return advances from theme selection to the flow page,
            // same as the Next button. On the flow page itself, the user
            // uses its own Get Started button.
            if !showFlowPage {
                themeManager.select(selectedTheme)
                withAnimation(.easeInOut(duration: 0.4)) { showFlowPage = true }
                return .handled
            }
            return .ignored
        }
    }

    // MARK: - Theme Selection Page

    private var themeSelectionPage: some View {
        ZStack {
            selectedTheme.backgroundGradient(for: effectiveColorScheme)
                .animation(.easeInOut(duration: 0.5), value: selectedIndex)
                .animation(.easeInOut(duration: 0.3), value: previewDark)
                .ignoresSafeArea()

            RadialGradient(
                colors: [selectedTheme.onBackgroundText(for: effectiveColorScheme).opacity(0.1), .clear],
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
                        .foregroundStyle(selectedTheme.onBackgroundText(for: effectiveColorScheme))

                    Text("Smart breaks for your eyes")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(selectedTheme.onBackgroundText(for: effectiveColorScheme))
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
                    .foregroundStyle(selectedTheme.onBackgroundText(for: effectiveColorScheme))
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
                    .foregroundStyle(selectedTheme.onBackgroundText(for: effectiveColorScheme))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(selectedTheme.onBackgroundText(for: effectiveColorScheme).opacity(0.15))
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
                        .foregroundStyle(selectedTheme.backgroundTop(for: effectiveColorScheme))
                        .frame(width: 200, height: 48)
                        .background(selectedTheme.onBackgroundText(for: effectiveColorScheme))
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
        let fg = selectedTheme.onBackgroundText(for: effectiveColorScheme)
        return HStack(spacing: 60) {
            Button {
                withAnimation { navigatePrevious() }
            } label: {
                Image(systemName: "chevron.left.circle.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(fg.opacity(selectedIndex > 0 ? 1 : 0.3))
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
                    .foregroundStyle(fg.opacity(selectedIndex < themes.count - 1 ? 1 : 0.3))
            }
            .buttonStyle(.plain)
            .disabled(selectedIndex == themes.count - 1)
        }
    }

    // MARK: - Dark Preview Toggle

    private var darkPreviewToggle: some View {
        let fg = selectedTheme.onBackgroundText(for: effectiveColorScheme)
        return Button {
            withAnimation(.easeInOut(duration: 0.3)) { previewDark.toggle() }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: previewDark ? "sun.max.fill" : "moon.fill")
                    .font(.system(size: 13, weight: .medium))
                Text(previewDark ? "Preview light" : "Preview dark")
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundStyle(fg)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(fg.opacity(0.15))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .help(previewDark ? "Show theme's light colors" : "Preview how the theme looks in dark mode")
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
