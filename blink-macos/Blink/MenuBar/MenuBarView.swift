import SwiftUI
import BlinkCore

struct MenuBarView: View {
    @ObservedObject var appState: AppState
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var updateChecker: UpdateChecker
    @Environment(\.colorScheme) private var colorScheme

    private var theme: BlinkTheme { themeManager.current }
    private var accentColor: Color { theme.accent(for: colorScheme) }

    var body: some View {
        VStack(spacing: 0) {
            // Header with icon
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(theme.backgroundTop)
                        .frame(width: 32, height: 32)
                    Image(theme.iconAsset)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 34, height: 34)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .frame(width: 30, height: 30)
                        .clipped()
                }
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Blink")
                        .font(.system(size: 14, weight: .semibold))
                    flowStateBadge
                }

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 12)

            // Update banner (only for direct/Homebrew installs, not App Store)
            if !UpdateChecker.isAppStore, updateChecker.updateAvailable, let version = updateChecker.latestVersion {
                updateBanner(version: version)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 4)
            }

            // Timer card
            VStack(spacing: 12) {
                if !appState.hasAccessibilityPermission {
                    permissionBanner
                } else {
                    timerCard
                }
            }
            .padding(.horizontal, 12)

            // Stats
            HStack(spacing: 6) {
                Image(systemName: "eye")
                    .font(.system(size: 11))
                    .foregroundStyle(accentColor)
                Text("\(appState.breaksTakenToday) breaks today")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.primary.opacity(0.7))
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 10)

            Divider()
                .padding(.horizontal, 12)

            // Take Break Now button
            if appState.hasAccessibilityPermission && !appState.isBreakPrompted {
                Button {
                    appState.showBreakPrompt()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "eye")
                            .font(.system(size: 12))
                        Text("Take Break Now")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 30)
                    .background(accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.top, 4)
            }

            // Bottom buttons
            HStack(spacing: 12) {
                Button {
                    WhyExistWindowController.shared.show()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "questionmark.circle")
                            .font(.system(size: 11))
                        Text("About")
                            .font(.system(size: 12))
                    }
                    .foregroundStyle(.primary.opacity(0.6))
                }
                .buttonStyle(.plain)

                Button {
                    PreferencesWindowController.shared.show(
                        appState: appState,
                        themeManager: themeManager
                    )
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "gear")
                            .font(.system(size: 11))
                        Text("Preferences")
                            .font(.system(size: 12))
                    }
                    .foregroundStyle(.primary.opacity(0.6))
                }
                .buttonStyle(.plain)

                Spacer()

                Button {
                    NSApp.terminate(nil)
                } label: {
                    Text("Quit")
                        .font(.system(size: 12))
                        .foregroundStyle(.primary.opacity(0.4))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .frame(width: 280)
    }

    // MARK: - Timer Card

    private var timerCard: some View {
        VStack(spacing: 10) {
            // Countdown
            Text(formatTime(appState.remainingSeconds))
                .font(.system(size: 40, weight: .light, design: .monospaced))
                .foregroundStyle(.primary)

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(accentColor.opacity(0.15))
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(accentColor)
                        .frame(width: geo.size.width * appState.timerStateMachine.progress, height: 6)
                        .animation(.linear(duration: 1), value: appState.timerStateMachine.progress)
                }
            }
            .frame(height: 6)

            // State label
            HStack {
                Text(flowStateLabel)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(timerDurationLabel)
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(14)
        .background(accentColor.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Update Banner

    @State private var showBrewCommand = false
    @State private var brewCommandCopied = false

    private func updateBanner(version: String) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(accentColor)

                Text("v\(version) available")
                    .font(.system(size: 12, weight: .medium))

                Spacer()
            }

            HStack(spacing: 6) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showBrewCommand.toggle()
                    }
                } label: {
                    Text("Homebrew")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .frame(maxWidth: .infinity)
                        .background(accentColor)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                if let url = updateChecker.downloadURL {
                    Button {
                        NSWorkspace.shared.open(url)
                    } label: {
                        Text("Download DMG")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(accentColor)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .frame(maxWidth: .infinity)
                            .background(accentColor.opacity(0.15))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }

            if showBrewCommand {
                HStack(spacing: 0) {
                    Text("$ ")
                        .foregroundStyle(.secondary)
                    + Text(UpdateChecker.brewCommand)
                        .foregroundStyle(.primary)

                    Spacer(minLength: 8)

                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(UpdateChecker.brewCommand, forType: .string)
                        brewCommandCopied = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            brewCommandCopied = false
                        }
                    } label: {
                        Image(systemName: brewCommandCopied ? "checkmark" : "doc.on.clipboard")
                            .font(.system(size: 12))
                            .foregroundStyle(brewCommandCopied ? .green : accentColor)
                            .frame(width: 24, height: 24)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .font(.system(size: 11, design: .monospaced))
                .padding(8)
                .background(Color(nsColor: .textBackgroundColor).opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(Color.primary.opacity(0.1))
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(10)
        .background(accentColor.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Flow State

    private var flowStateBadge: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(flowStateColor)
                .frame(width: 6, height: 6)
            Text(flowStateBadgeLabel)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.primary.opacity(0.7))
        }
    }

    private var flowStateColor: Color {
        if appState.isVideoPlaying { return .green }
        switch appState.flowState {
        case .normal: return .gray
        case .flow, .deepFlow: return accentColor
        case .idle: return .orange
        case .meeting: return .red
        case .breakPrompted: return accentColor
        }
    }

    private var flowStateBadgeLabel: String {
        if appState.isVideoPlaying { return "Video" }
        switch appState.flowState {
        case .normal: return "Working"
        case .flow: return "In flow"
        case .deepFlow: return "Deep flow"
        case .idle: return "Away"
        case .meeting: return "Meeting"
        case .breakPrompted: return "Break"
        }
    }

    private var flowStateLabel: String {
        if appState.isVideoPlaying { return "Video playing — timer paused" }
        switch appState.flowState {
        case .normal: return "Timer running"
        case .flow: return "In flow — extended to 30 min"
        case .deepFlow: return "Deep flow — extended to 40 min"
        case .idle: return "Away — timer paused"
        case .meeting: return "In meeting — timer paused"
        case .breakPrompted: return "Break time"
        }
    }

    private var timerDurationLabel: String {
        let total = Int(appState.timerStateMachine.timerDuration)
        return "\(total / 60) min"
    }

    // MARK: - Permission Banner

    private var permissionBanner: some View {
        VStack(spacing: 8) {
            Image(systemName: "lock.shield")
                .font(.system(size: 24))
                .foregroundStyle(accentColor)

            Text("Grant Accessibility for smart break timing")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                PermissionManager.openAccessibilitySettings()
            } label: {
                Text("Open Settings")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 28)
                    .background(accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(accentColor.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Helpers

    private func formatTime(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

#Preview("Menu Bar - Peach") {
    MenuBarView(appState: AppState(preview: true))
        .environmentObject(ThemeManager.shared)
        .environmentObject(UpdateChecker.shared)
}
