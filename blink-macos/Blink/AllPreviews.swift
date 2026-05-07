import SwiftUI
import BlinkCore

// MARK: - Menu Bar

#Preview("MenuBar — Light") {
    ScrollView {
        VStack(spacing: 20) {
            ForEach(BlinkTheme.allLight) { theme in
                VStack(spacing: 4) {
                    Text(theme.name).font(.caption).foregroundStyle(.secondary)
                    menuBarCard(theme)
                }
            }
        }
        .padding(20)
    }
    .frame(width: 340, height: 900)
    .preferredColorScheme(.light)
}

#Preview("MenuBar — Dark") {
    ScrollView {
        VStack(spacing: 20) {
            ForEach(BlinkTheme.allLight) { theme in
                VStack(spacing: 4) {
                    Text(theme.name).font(.caption).foregroundStyle(.secondary)
                    menuBarCard(theme)
                }
            }
        }
        .padding(20)
    }
    .frame(width: 340, height: 900)
    .preferredColorScheme(.dark)
}

// MARK: - Settings

#Preview("Settings — Light") {
    VStack(spacing: 20) {
        ForEach(["peach", "midnight", "mono"], id: \.self) { id in
            let theme = BlinkTheme.named(id)
            VStack(spacing: 4) {
                Text(theme.name).font(.caption).foregroundStyle(.secondary)
                settingsCard(theme)
            }
        }
    }
    .padding(20)
    .frame(width: 500, height: 1300)
    .preferredColorScheme(.light)
}

#Preview("Settings — Dark") {
    VStack(spacing: 20) {
        ForEach(["peach", "midnight", "mono"], id: \.self) { id in
            let theme = BlinkTheme.named(id)
            VStack(spacing: 4) {
                Text(theme.name).font(.caption).foregroundStyle(.secondary)
                settingsCard(theme)
            }
        }
    }
    .padding(20)
    .frame(width: 500, height: 1300)
    .preferredColorScheme(.dark)
}

// MARK: - WhyExist

#Preview("WhyExist — Light") {
    VStack(spacing: 20) {
        ForEach(["peach", "midnight", "mono"], id: \.self) { id in
            let theme = BlinkTheme.named(id)
            VStack(spacing: 4) {
                Text(theme.name).font(.caption).foregroundStyle(.secondary)
                WhyExistView(theme: theme, onDismiss: {})
                    .frame(width: 500, height: 420)
                    .background(Color(nsColor: .windowBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }
    .padding(20)
    .frame(width: 560, height: 1400)
    .preferredColorScheme(.light)
}

#Preview("WhyExist — Dark") {
    VStack(spacing: 20) {
        ForEach(["peach", "midnight", "mono"], id: \.self) { id in
            let theme = BlinkTheme.named(id)
            VStack(spacing: 4) {
                Text(theme.name).font(.caption).foregroundStyle(.secondary)
                WhyExistView(theme: theme, onDismiss: {})
                    .frame(width: 500, height: 420)
                    .background(Color(nsColor: .windowBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }
    .padding(20)
    .frame(width: 560, height: 1400)
    .preferredColorScheme(.dark)
}

// MARK: - Break Timer

#Preview("Break Timer — Light") {
    VStack(spacing: 20) {
        ForEach(["peach", "midnight", "mono"], id: \.self) { id in
            VStack(spacing: 4) {
                Text(BlinkTheme.named(id).name).font(.caption).foregroundStyle(.secondary)
                BreakTimerPreviewCard(theme: BlinkTheme.named(id))
            }
        }
    }
    .padding(20)
    .frame(width: 440, height: 1200)
    .preferredColorScheme(.light)
}

#Preview("Break Timer — Dark") {
    VStack(spacing: 20) {
        ForEach(["peach", "midnight", "mono"], id: \.self) { id in
            VStack(spacing: 4) {
                Text(BlinkTheme.named(id).name).font(.caption).foregroundStyle(.secondary)
                BreakTimerPreviewCard(theme: BlinkTheme.named(id))
            }
        }
    }
    .padding(20)
    .frame(width: 440, height: 1200)
    .preferredColorScheme(.dark)
}

// MARK: - Onboarding

#Preview("Onboarding — Light") {
    OnboardingView(themeManager: ThemeManager.shared, onComplete: {})
        .frame(width: 800, height: 600)
        .preferredColorScheme(.light)
}

#Preview("Onboarding — Dark") {
    OnboardingView(themeManager: ThemeManager.shared, isDarkMode: true, onComplete: {})
        .frame(width: 800, height: 600)
        .preferredColorScheme(.dark)
}

// MARK: - Helpers

@MainActor
private func menuBarCard(_ theme: BlinkTheme) -> some View {
    MenuBarView(appState: AppState(preview: true))
        .environmentObject(ThemeManager.preview(theme))
        .environmentObject(UpdateChecker.shared)
        .frame(width: 280)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .shadow(radius: 4)
}

@MainActor
private func settingsCard(_ theme: BlinkTheme) -> some View {
    SettingsView(appState: AppState(preview: true))
        .environmentObject(ThemeManager.preview(theme))
        .frame(width: 440, height: 380)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .shadow(radius: 4)
}

private struct BreakTimerPreviewCard: View {
    let theme: BlinkTheme
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let bg = theme.overlayBackground(for: colorScheme)
        let fg = theme.overlayText(for: colorScheme)
        let accent = theme.accent(for: colorScheme)

        ZStack {
            bg
            VStack(spacing: 24) {
                Image(systemName: "eye")
                    .font(.system(size: 36, weight: .ultraLight))
                    .foregroundStyle(accent.opacity(0.8))

                Text("Look at something far away")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(fg)

                ZStack {
                    Circle()
                        .stroke(accent.opacity(0.15), lineWidth: 3)
                        .frame(width: 100, height: 100)
                    Circle()
                        .trim(from: 0, to: 0.65)
                        .stroke(accent, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .frame(width: 100, height: 100)
                        .rotationEffect(.degrees(-90))
                    Text("13")
                        .font(.system(size: 40, weight: .ultraLight, design: .monospaced))
                        .foregroundStyle(fg)
                }

                HStack(spacing: 20) {
                    keyHint("esc", "Skip", fg: fg, accent: accent)
                    keyHint("→", "Extend", fg: fg, accent: accent)
                }
            }
            .padding(24)
        }
        .frame(width: 380, height: 350)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func keyHint(_ key: String, _ label: String, fg: Color, accent: Color) -> some View {
        HStack(spacing: 6) {
            Text(key)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(fg.opacity(0.9))
                .frame(minWidth: 28, minHeight: 22)
                .padding(.horizontal, 6)
                .background(accent.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 4))
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(fg.opacity(0.5))
        }
    }
}
