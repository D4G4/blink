import SwiftUI

/// Standalone "Why do I exist?" view — used in onboarding and from menu bar.
/// Shows 20-20-20 rule education with 2 pages.
struct WhyExistView: View {
    let theme: BlinkTheme
    let onDismiss: (() -> Void)?
    let onContinue: (() -> Void)?

    @Environment(\.colorScheme) private var colorScheme

    @State private var page: Int = 0

    /// Use as a dialog overlay (with dismiss)
    init(theme: BlinkTheme, onDismiss: @escaping () -> Void) {
        self.theme = theme
        self.onDismiss = onDismiss
        self.onContinue = nil
    }

    /// Use as an onboarding step (with continue)
    init(theme: BlinkTheme, onContinue: @escaping () -> Void) {
        self.theme = theme
        self.onDismiss = nil
        self.onContinue = onContinue
    }

    var body: some View {
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
                            .foregroundStyle(theme.accent(for: colorScheme))
                        }
                        .buttonStyle(.plain)
                    } else {
                        Button {
                            if let onContinue {
                                onContinue()
                            } else {
                                onDismiss?()
                            }
                        } label: {
                            Text(onContinue != nil ? "Choose Theme" : "Got it")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(theme.textOnAccent(for: colorScheme))
                                .frame(width: 120, height: 34)
                                .background(theme.accent(for: colorScheme))
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
        .onKeyPress(.escape) {
            onDismiss?()
            return .handled
        }
        .onKeyPress(.leftArrow) {
            if page > 0 { withAnimation(.easeInOut(duration: 0.3)) { page = 0 } }
            return .handled
        }
        .onKeyPress(.rightArrow) {
            if page < 1 { withAnimation(.easeInOut(duration: 0.3)) { page = 1 } }
            return .handled
        }
    }

    // MARK: - Page 1: The Rule

    private var pageRule: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                Text("The 20-20-20 Rule")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                Text("Recommended by optometrists since 1991")
                    .font(.system(size: 15))
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
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                Text("Breaks that respect your workflow")
                    .font(.system(size: 15))
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
                           text: "When a native video app (TV, VLC, IINA, Netflix.app, etc.) is frontmost, the timer pauses — you're already resting your focus.")
                featureRow(icon: "video", title: "Meeting detection",
                           text: "Pauses automatically during calls so you're never interrupted in a meeting.")
            }
            .padding(.horizontal, 36)

            Spacer()
        }
    }

    // MARK: - Components

    private func ruleCard(number: String, unit: String, description: String, icon: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundStyle(theme.accent(for: colorScheme))
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(number)
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                Text(unit)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            Text(description)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(theme.accent(for: colorScheme).opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func factRow(text: String, icon: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(theme.accent(for: colorScheme))
                .frame(width: 22)
            Text(text).font(.system(size: 15))
        }
    }

    private func featureRow(icon: String, title: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(theme.accent(for: colorScheme))
                .frame(width: 26)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                Text(text)
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
