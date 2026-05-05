import SwiftUI

struct OnboardingView: View {
    @ObservedObject var themeManager: ThemeManager
    let onComplete: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedIndex: Int = 0
    @State private var hasSetInitialIndex: Bool = false
    @State private var iconScale: CGFloat = 0.5
    @State private var iconOpacity: Double = 0
    @State private var showWhySheet: Bool = false

    private let themes = BlinkTheme.all

    private var selectedTheme: BlinkTheme {
        themes[max(0, min(selectedIndex, themes.count - 1))]
    }

    var body: some View {
        ZStack {
            // Background gradient that changes with theme
            selectedTheme.backgroundGradient(for: colorScheme)
                .animation(.easeInOut(duration: 0.5), value: selectedIndex)
                .animation(.easeInOut(duration: 0.3), value: colorScheme)
                .ignoresSafeArea()

            // Subtle radial glow behind icon
            RadialGradient(
                colors: [selectedTheme.onBackgroundText(for: colorScheme).opacity(0.1), .clear],
                center: .center,
                startRadius: 50,
                endRadius: 300
            )

            VStack(spacing: 0) {
                Spacer()

                // Welcome text
                VStack(spacing: 8) {
                    Text("Welcome to Blink")
                        .font(.system(size: 38, weight: .bold, design: .rounded))
                        .foregroundStyle(selectedTheme.onBackgroundText(for: colorScheme))

                    Text("Smart breaks for your eyes")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(selectedTheme.onBackgroundText(for: colorScheme).opacity(0.7))
                }
                .padding(.bottom, 48)

                // App icon — large and centered
                // Icons have opaque black corners (no alpha), so we scale the image
                // slightly larger than the clip to cut into the content area past the corners
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

                // Theme name
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

                    // Dots
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

                // Get started button
                Button {
                    themeManager.select(selectedTheme)
                    themeManager.hasCompletedOnboarding = true
                    onComplete()
                } label: {
                    Text("Get Started")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(selectedTheme.backgroundBottom)
                        .frame(width: 200, height: 48)
                        .background(selectedTheme.onBackgroundText(for: colorScheme))
                        .clipShape(Capsule())
                        .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
                }
                .buttonStyle(.plain)
                .padding(.bottom, 16)

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
                .padding(.bottom, 32)

            }

            // "Why do I exist" overlay
            if showWhySheet {
                WhyExistSheet(theme: selectedTheme) {
                    withAnimation(.spring(response: 0.3)) { showWhySheet = false }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .onAppear {
            if !hasSetInitialIndex {
                hasSetInitialIndex = true
                let defaultThemeID = colorScheme == .dark ? "midnight" : "peach"
                selectedIndex = themes.firstIndex { $0.id == defaultThemeID } ?? 0
            }
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

// MARK: - Why do I exist sheet

private struct WhyExistSheet: View {
    let theme: BlinkTheme
    let onDismiss: () -> Void

    @State private var page: Int = 0

    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            VStack(spacing: 0) {
                // Sliding pages
                ZStack {
                    if page == 0 {
                        pageRule
                            .transition(.asymmetric(
                                insertion: .move(edge: .leading),
                                removal: .move(edge: .leading)
                            ))
                    } else {
                        pageHowItWorks
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing),
                                removal: .move(edge: .trailing)
                            ))
                    }
                }
                .clipped()

                // Bottom bar — fixed 3-column layout
                HStack {
                    // Left
                    HStack {
                        if page == 1 {
                            Button {
                                withAnimation(.easeInOut(duration: 0.3)) { page = 0 }
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "chevron.left")
                                    Text("Back")
                                }
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .frame(width: 150, height: 40, alignment: .leading)

                    Spacer()

                    // Center — dots
                    HStack(spacing: 6) {
                        Circle().fill(.primary.opacity(page == 0 ? 1 : 0.3)).frame(width: 7, height: 7)
                        Circle().fill(.primary.opacity(page == 1 ? 1 : 0.3)).frame(width: 7, height: 7)
                    }
                    .frame(height: 40)

                    Spacer()

                    // Right
                    HStack {
                        if page == 0 {
                            Button {
                                withAnimation(.easeInOut(duration: 0.3)) { page = 1 }
                            } label: {
                                HStack(spacing: 4) {
                                    Text("How Blink works")
                                    Image(systemName: "chevron.right")
                                }
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(theme.accent)
                            }
                            .buttonStyle(.plain)
                        } else {
                            Button {
                                onDismiss()
                            } label: {
                                Text("Got it")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .frame(width: 100, height: 34)
                                    .background(theme.accent)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .frame(width: 150, height: 40, alignment: .trailing)
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 20)
            }
            .frame(width: 580, height: 520)
            .background(Color(nsColor: .windowBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(color: .black.opacity(0.3), radius: 30, y: 10)
            .onKeyPress(.escape) { onDismiss(); return .handled }
            .onKeyPress(.leftArrow) {
                if page > 0 { withAnimation(.easeInOut(duration: 0.3)) { page = 0 } }
                return .handled
            }
            .onKeyPress(.rightArrow) {
                if page < 1 { withAnimation(.easeInOut(duration: 0.3)) { page = 1 } }
                return .handled
            }
        }
    }

    // MARK: - Page 1: The Rule

    private var pageRule: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                Text("The 20-20-20 Rule")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                Text("Recommended by optometrists since 1991")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 32).padding(.bottom, 24)

            HStack(spacing: 20) {
                ruleCard(number: "20", unit: "min",
                         description: "Every 20 minutes\nof screen time", icon: "clock")
                ruleCard(number: "20", unit: "sec",
                         description: "Take a 20-second\nbreak", icon: "pause.circle")
                ruleCard(number: "20", unit: "feet",
                         description: "Look at something\n20 feet away", icon: "eye")
            }
            .padding(.horizontal, 28)

            VStack(alignment: .leading, spacing: 12) {
                factRow(text: "Your blink rate drops from 15/min to 4/min during screen work",
                        icon: "exclamationmark.triangle")
                factRow(text: "This causes dry eyes, headaches, and blurred vision",
                        icon: "eye.trianglebadge.exclamationmark")
                factRow(text: "A 20-second break lets your eye muscles relax and reset",
                        icon: "checkmark.circle")
                factRow(text: "Blink detects your work patterns so breaks come at the right time",
                        icon: "sparkles")
            }
            .padding(.horizontal, 36).padding(.top, 28)

            Spacer()
        }
    }

    // MARK: - Page 2: How Blink Works

    private var pageHowItWorks: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                Text("How Blink Works")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                Text("Breaks that respect your workflow")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 32).padding(.bottom, 28)

            VStack(alignment: .leading, spacing: 18) {
                featureRow(icon: "brain.head.profile", title: "Flow detection",
                           text: "Monitors your typing rhythm and app switching to detect deep focus. Extends the timer so you're not interrupted mid-thought.")
                featureRow(icon: "hand.raised", title: "Natural pause waiting",
                           text: "When you're focused, Blink waits for a natural pause before prompting — no jarring mid-keystroke popups.")
                featureRow(icon: "figure.walk", title: "Walk-away detection",
                           text: "Step away from your computer? Blink counts that as a break and silently resets the timer.")
                featureRow(icon: "play.rectangle", title: "Video awareness",
                           text: "Detects when you're watching video and pauses — you're already resting your focus.")
                featureRow(icon: "video", title: "Meeting detection",
                           text: "Pauses automatically during calls so you're never interrupted in a meeting.")
            }
            .padding(.horizontal, 36)

            Spacer()
        }
    }

    // MARK: - Components

    private func ruleCard(number: String, unit: String, description: String, icon: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundStyle(theme.accent)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(number)
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                Text(unit)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            Text(description)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(theme.accent.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func factRow(text: String, icon: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(theme.accent)
                .frame(width: 20)
            Text(text).font(.system(size: 13))
        }
    }

    private func featureRow(icon: String, title: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(theme.accent)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                Text(text)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

#Preview("Onboarding") {
    OnboardingView(
        themeManager: ThemeManager.shared,
        onComplete: {}
    )
    .frame(width: 900, height: 650)
}

#Preview("Why Sheet") {
    ZStack {
        BlinkTheme.peach.backgroundGradient
        WhyExistSheet(theme: .peach, onDismiss: {})
    }
    .frame(width: 700, height: 550)
}

