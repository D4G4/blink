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

                Button {
                    appState.togglePause()
                } label: {
                    Image(systemName: appState.isPaused ? "play.fill" : "pause.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                        .background(Color.primary.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .help(appState.isPaused ? "Resume Blink" : "Pause Blink")
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 16)

            // Update banner (only for direct/Homebrew installs, not App Store)
            if !UpdateChecker.isAppStore, updateChecker.updateAvailable, let version = updateChecker.latestVersion {
                updateBanner(version: version)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 4)
            }

            // Mic always-on — small link, opens detail window
            if appState.micAlwaysOnWarning {
                Button {
                    MicWarningWindowController.shared.show(appState: appState)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "mic.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(.orange)
                        Text("Mic always on — tap for details")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.orange)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9))
                            .foregroundStyle(.orange)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.orange.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.bottom, 4)
            }

            // Timer card + conditional mode chip. Smart users see no
            // chip (it's the default — nothing to communicate). Simple-
            // deliberate users see a subtle "Tap to change" hint. Missing-
            // IM users see an accent-toned CTA to re-enable Smart timing.
            VStack(spacing: 8) {
                timerCard
                if !appState.hasInputMonitoringPermission {
                    detectionModeIndicator
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
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 14)

            Divider()
                .padding(.horizontal, 12)

            // Take Break Now button — secondary treatment (outlined accent).
            // The break timer ticks down on its own; the manual trigger is
            // a fallback, not the primary action.
            if !appState.isBreakPrompted && !appState.isPaused {
                Button {
                    UIActionLogger.buttonTapped("Take Break Now", context: "MenuBar")
                    appState.showBreakPrompt()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "eye")
                            .font(.system(size: 12))
                        Text("Take Break Now")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundStyle(accentColor)
                    .frame(maxWidth: .infinity)
                    .frame(height: 32)
                    .background(accentColor.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.top, 14)
            }

            Spacer()
                .frame(height: 10)

            // Eye Exercise button — primary treatment (filled accent).
            // The exercise is the discoverable habit-builder we want to
            // pull users into, so it gets the hero CTA styling here.
            Button {
                UIActionLogger.buttonTapped("Eye Exercise", context: "MenuBar")
                let currentTheme = themeManager.current
                // Dismiss the MenuBarExtra popover
                dismissMenuBarPopover()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    GaborExerciseWindowController.shared.show(theme: currentTheme)
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "eye.circle")
                        .font(.system(size: 12))
                    Text("Eye Exercise")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundStyle(theme.textOnAccent(for: colorScheme))
                .frame(maxWidth: .infinity)
                .frame(height: 32)
                .background(accentColor)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)

            // Bottom buttons
            HStack(spacing: 12) {
                Button {
                    UIActionLogger.buttonTapped("About", context: "MenuBar")
                    WhyExistWindowController.shared.show()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "questionmark.circle")
                            .font(.system(size: 11))
                        Text("About")
                            .font(.system(size: 12))
                    }
                    .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)

                Button {
                    UIActionLogger.buttonTapped("Preferences", context: "MenuBar")
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
                    .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)

                Spacer()

                Button {
                    UIActionLogger.buttonTapped("Quit", context: "MenuBar")
                    NSApp.terminate(nil)
                } label: {
                    Text("Quit")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)
        }
        .frame(width: 280)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func dismissMenuBarPopover() {
        // The MenuBarExtra popover is the key window when interacting with it.
        // Close it, then fall back to MenuBarController if needed.
        if let keyWindow = NSApp.keyWindow, keyWindow is NSPanel {
            keyWindow.close()
            return
        }
        MenuBarController.shared.close()
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
                        .frame(width: geo.size.width * timerProgress, height: 6)
                        .animation(.linear(duration: 1), value: timerProgress)
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
                        .foregroundStyle(theme.textOnAccent(for: colorScheme))
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
                .foregroundStyle(.secondary)
        }
    }

    private var flowStateColor: Color {
        if appState.isVideoPlaying { return .green }
        switch appState.displayState {
        case .working: return .gray
        case .away: return .orange
        case .meeting: return .red
        case .onBreak: return accentColor
        }
    }

    private var flowStateBadgeLabel: String {
        if appState.isVideoPlaying { return "Video" }
        switch appState.displayState {
        case .working: return "Working"
        case .away: return "Away"
        case .meeting: return "Mic active"
        case .onBreak: return "Break"
        }
    }

    private var flowStateLabel: String {
        if appState.isPaused { return "Paused" }
        if appState.isVideoPlaying { return "Video playing — timer paused" }
        switch appState.displayState {
        case .working: return "Timer running"
        case .away: return "Away — timer paused"
        case .meeting: return "Mic active — timer paused"
        case .onBreak: return "Break time"
        }
    }

    private var timerDurationLabel: String {
        let total = Int(appState.timerTotal)
        return "\(total / 60) min"
    }

    private var timerProgress: Double {
        guard appState.timerTotal > 0 else { return 1.0 }
        return max(0, min(1.0, 1.0 - appState.remainingSeconds / appState.timerTotal))
    }



    // MARK: - Detection Mode Indicator

    /// Conditional chip below the timer card. Only rendered when
    /// `hasInputMonitoringPermission == false` — Smart-mode users see
    /// nothing here (the default needs no callout). Two variants:
    ///   - **Simple deliberate** (basicModeOptIn=true): subtle hourglass
    ///     chip. Chevron implies tappability → opens Preferences → Flow.
    ///   - **Missing/revoked IM** (basicModeOptIn=false): accent-toned
    ///     CTA → opens System Settings → Input Monitoring.
    private var detectionModeIndicator: some View {
        let deliberateSimple = UserDefaults.standard.bool(forKey: "basicModeOptIn")

        return Button {
            if deliberateSimple {
                UIActionLogger.buttonTapped("Open Preferences → Flow (from Simple-mode chip)")
                PreferencesWindowController.shared.show(
                    appState: appState,
                    themeManager: themeManager,
                    initialTab: 2  // Flow tab
                )
            } else {
                UIActionLogger.buttonTapped("Enable smart timing (from missing-IM chip)")
                PermissionManager.openInputMonitoringSettings()
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: deliberateSimple ? "hourglass" : "exclamationmark.triangle.fill")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(deliberateSimple ? .secondary : accentColor)
                Text(deliberateSimple ? "Simple mode" : "Smart timing off — Enable")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.primary)
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background((deliberateSimple ? Color.primary : accentColor).opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private func formatTime(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

// MARK: - Previews
//
// Smart mode (default) is the no-chip baseline — the default preview
// covers that. Below are the two states where the chip renders:
// deliberate Simple (subtle "tap to change") and missing IM (accent CTA).
// AppState(preview: true) hard-codes hasInputMonitoringPermission=true,
// so these flip the flag (and the basicModeOptIn UserDefaults key the
// chip reads to pick its variant). ThemeManager.preview(_:) returns an
// isolated instance so Midnight previews don't mutate the singleton.

#Preview("Smart mode — default (Peach)") {
    UserDefaults.standard.set(false, forKey: "basicModeOptIn")
    return MenuBarView(appState: AppState(preview: true))
        .environmentObject(ThemeManager.preview(.peach))
        .environmentObject(UpdateChecker.shared)
}

#Preview("Simple mode, deliberate (Peach)") {
    UserDefaults.standard.set(true, forKey: "basicModeOptIn")
    let state = AppState(preview: true)
    state.hasInputMonitoringPermission = false
    return MenuBarView(appState: state)
        .environmentObject(ThemeManager.preview(.peach))
        .environmentObject(UpdateChecker.shared)
}

#Preview("Missing IM permission (Peach)") {
    UserDefaults.standard.set(false, forKey: "basicModeOptIn")
    let state = AppState(preview: true)
    state.hasInputMonitoringPermission = false
    return MenuBarView(appState: state)
        .environmentObject(ThemeManager.preview(.peach))
        .environmentObject(UpdateChecker.shared)
}

