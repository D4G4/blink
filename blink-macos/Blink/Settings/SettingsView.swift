import SwiftUI
import ServiceManagement
import BlinkCore

struct SettingsView: View {
    @ObservedObject var appState: AppState
    @EnvironmentObject var themeManager: ThemeManager
    @AppStorage("baseInterval") private var baseInterval: Double = 20
    @AppStorage("flowSensitivity") private var flowSensitivity: Double = FlowSensitivityView.Preset.balanced.value
    @AppStorage("launchAtLogin") private var launchAtLogin: Bool = false
    @AppStorage("showTimerInMenuBar") private var showTimerInMenuBar: Bool = false
    @AppStorage("useDarkOverlay") private var useDarkOverlay: Bool = false
    @AppStorage("pauseDuringCalls") private var pauseDuringCalls: Bool = true
    @AppStorage("chimeEnabled") private var chimeEnabled: Bool = true
    @AppStorage("chimeID") private var chimeID: String = ChimePlayer.defaultChimeID
    @AppStorage("chimeVolume") private var chimeVolume: Double = ChimePlayer.defaultVolume
    @AppStorage("breakSuggestionsEnabled") private var breakSuggestionsEnabled: Bool = true

    @State private var showSuggestionsHelp: Bool = false
    
    @Environment(\.colorScheme) private var colorScheme
    private var theme: BlinkTheme { themeManager.current }
    private var accentColor: Color { theme.accent(for: colorScheme) }
    
    @State private var selectedTab: Int

    init(appState: AppState, initialTab: Int = 0) {
        self.appState = appState
        self._selectedTab = State(initialValue: initialTab)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Custom tab bar
            HStack(spacing: 0) {
                tabButton(icon: "gear", label: "General", index: 0)
                tabButton(icon: "paintpalette", label: "Theme", index: 1)
                tabButton(icon: "brain", label: "Flow", index: 2)
                tabButton(icon: "info.circle", label: "About", index: 3)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)
            
            Divider()
            
            // Content
            ScrollView {
                Group {
                    switch selectedTab {
                    case 0: generalContent
                    case 1: themeContent
                    case 2: flowContent
                    case 3: aboutContent
                    default: generalContent
                    }
                }
                .padding(20)
            }
        }
        // Width locked to 440 (the design target); height fills the
        // hosting window so the ScrollView has as much room as available.
        // Previously height was also pinned to 440, which left wasted
        // space in the actual prefs window (520×450) and broke snapshots
        // that wanted to render the General tab end-to-end with icons.
        .frame(width: 440)
        .frame(maxHeight: .infinity)
        .tint(accentColor)
    }
    
    // MARK: - Tab Button
    
    private func tabButton(icon: String, label: String, index: Int) -> some View {
        Button {
            UIActionLogger.tabSelected(label)
            withAnimation(.easeInOut(duration: 0.15)) { selectedTab = index }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                Text(label)
                    .font(.system(size: 10))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .foregroundStyle(selectedTab == index ? accentColor : .secondary)
            .contentShape(Rectangle())
            .background(
                selectedTab == index
                ? accentColor.opacity(0.1)
                : Color.clear
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - General
    
    private var generalContent: some View {
        VStack(alignment: .leading, spacing: 20) {

            settingsSection("Menu Bar") {
                settingsToggleWithIcon(
                    "Show countdown timer",
                    icon: {
                        CountdownTimerIcon(accent: accentColor, foreground: .primary)
                    },
                    isOn: $showTimerInMenuBar
                )
            }

            settingsSection("Break Screen") {
                settingsToggleWithIcon(
                    "Use dark overlay",
                    icon: {
                        DarkOverlayIcon(accent: accentColor, foreground: .primary)
                    },
                    isOn: $useDarkOverlay
                )
                settingsCaption("Pure black background instead of themed colors")

                SmartSuggestionsSettingControls(
                    theme: theme,
                    accentColor: accentColor,
                    isOn: $breakSuggestionsEnabled,
                    showHelp: $showSuggestionsHelp
                )
            }

            settingsSection("Break-End Chime") {
                settingsToggleWithIcon("Play chime when break ends", systemImage: "bell.fill", isOn: $chimeEnabled)
                if chimeEnabled {
                    settingsRow("Sound") {
                        HStack(spacing: 8) {
                            Picker("", selection: $chimeID) {
                                ForEach(ChimePlayer.Chime.all) { chime in
                                    Text(chime.displayName).tag(chime.id)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 170)
                            Button {
                                UIActionLogger.buttonTapped("Preview Chime", context: chimeID)
                                ChimePlayer.shared.play(id: chimeID, volume: chimeVolume)
                            } label: {
                                Image(systemName: "play.circle.fill")
                                    .font(.system(size: 18))
                                    .foregroundStyle(accentColor)
                            }
                            .buttonStyle(.plain)
                            .help("Preview")
                        }
                    }
                    settingsRow("Volume") {
                        HStack {
                            Slider(value: $chimeVolume, in: 0...1)
                                .tint(accentColor)
                            Text("\(Int(chimeVolume * 100))%")
                                .font(.system(size: 13, design: .monospaced))
                                .frame(width: 50)
                        }
                    }
                }
            }

            settingsSection("Mic Detection") {
                settingsToggleWithIcon("Pause timer during calls", systemImage: "mic.fill", isOn: $pauseDuringCalls)
                settingsCaption("Pauses breaks when your mic is active. Turn off if you use Dictation or Siri — they keep the mic open and will pause Blink permanently.")
            }

            settingsSection("Timer") {
                HStack(spacing: 10) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 17))
                        .foregroundStyle(accentColor)
                        .symbolRenderingMode(.hierarchical)
                        .frame(width: 32, alignment: .center)
                    settingsRow("Base interval") {
                        HStack {
                            Slider(value: $baseInterval, in: 10...45, step: 5)
                                .tint(accentColor)
                            Text("\(Int(baseInterval)) min")
                                .font(.system(size: 13, design: .monospaced))
                                .frame(width: 50)
                        }
                    }
                }
            }

            settingsSection("System") {
                settingsToggleWithIcon("Launch at login", systemImage: "power.circle.fill", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        UIActionLogger.settingChanged("launchAtLogin", value: "\(newValue)")
                        updateLaunchAtLogin(newValue)
                    }

                settingsToggleWithIcon("Debug notifications", systemImage: "ant.fill", isOn: $appState.debugNotifications)
                settingsCaption("Show toasts for timer resets, state changes, and idle detection")
                
                Button {
                    UIActionLogger.buttonTapped("Check for Updates")
                    BlinkUpdater.shared.checkForUpdates()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 11))
                        Text("Check for Updates")
                            .font(.system(size: 12))
                    }
                    .foregroundStyle(accentColor)
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
                
                Button {
                    UIActionLogger.buttonTapped("Restart Onboarding")
                    themeManager.hasCompletedOnboarding = false
                    let path = Bundle.main.bundleURL.absoluteString
                    let task = Process()
                    task.launchPath = "/usr/bin/open"
                    task.arguments = [path]
                    task.launch()
                    NSApp.terminate(nil)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 11))
                        Text("Restart Onboarding")
                            .font(.system(size: 12))
                    }
                    .foregroundStyle(accentColor)
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
                
                Button {
                    UIActionLogger.buttonTapped("Open Log Files")
                    LogExporter.revealInFinder()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "folder")
                            .font(.system(size: 11))
                        Text("Open Log Files")
                            .font(.system(size: 12))
                    }
                    .foregroundStyle(accentColor)
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
        }
    }
    
    // MARK: - Theme
    
    private var themeContent: some View {
        VStack(spacing: 24) {
            Text("Choose your theme")
                .font(.system(size: 16, weight: .semibold))
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 20), count: 3), spacing: 20) {
                ForEach(BlinkTheme.all) { t in
                    VStack(spacing: 8) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(t.backgroundTop)
                                .frame(width: 76, height: 76)
                            
                            Image(t.iconAsset)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 82, height: 82)
                                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                                .frame(width: 72, height: 72)
                                .clipped()
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(theme.id == t.id ? accentColor : .clear, lineWidth: 3)
                        )
                        .shadow(color: theme.id == t.id ? accentColor.opacity(0.3) : .clear, radius: 8)
                        .scaleEffect(theme.id == t.id ? 1.05 : 1.0)
                        .animation(.easeOut(duration: 0.2), value: theme.id)
                        
                        Text(t.name)
                            .font(.system(size: 12, weight: theme.id == t.id ? .semibold : .regular))
                            .foregroundStyle(theme.id == t.id ? .primary : .secondary)
                    }
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            themeManager.select(t)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Flow
    
    @State private var flowCheckDetail: String?

    private var flowContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            settingsSection("Detection Mode") {
                detectionModePicker
                settingsCaption(appState.hasInputMonitoringPermission
                    ? "Smart mode reads typing rhythm and mouse activity through Input Monitoring, so breaks land at natural pauses and adapt to flow state. Simple is a fixed 20-minute timer that asks for zero macOS permissions."
                    : "Simple timer mode runs without Input Monitoring or Accessibility — just a steady 20-minute timer that skips when you're idle. Switch to Smart for flow-aware break timing.")
            }

            // Sensitivity + Flow Check are only meaningful when Smart
            // mode is on. In Simple mode they're inert — sensitivity
            // doesn't drive anything, and Flow Check would just report
            // zeros. Replace both with a single prompt that switches
            // the user to Smart (which triggers the IM permission flow
            // if needed, via setDetectionMode hot-swap).
            if appState.hasInputMonitoringPermission {
                settingsSection("Flow Detection") {
                    FlowSensitivityView(
                        sensitivity: $flowSensitivity,
                        accentColor: accentColor,
                        foregroundColor: .primary,
                        style: .settings,
                        onResearchTapped: { [weak themeManager] in
                            UIActionLogger.buttonTapped("Read the Research", context: "Settings")
                            ResearchWindowController.shared.show(theme: themeManager?.current ?? .peach)
                        },
                        onLearnMoreTapped: {
                            UIActionLogger.buttonTapped("See impact", context: "Settings")
                            FlowLearnMoreWindowController.shared.show(theme: ThemeManager.shared.current)
                        }
                    )
                    .onChange(of: flowSensitivity) { _, newValue in
                        appState.engine.sensitivity = newValue
                    }
                }

                settingsSection("Flow Check") {
                    VStack(alignment: .leading, spacing: 10) {
                        Button {
                            let check = appState.engine.spotCheckFlow()
                            flowCheckDetail = check.description
                            Log.i("Flow spot check (Preferences):\n\(check.description)")
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "waveform.path.ecg")
                                    .font(.system(size: 12))
                                Text("Run Flow Check")
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .foregroundStyle(accentColor)
                        }
                        .buttonStyle(.plain)

                        if let detail = flowCheckDetail {
                            Text(detail)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                                .padding(10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.primary.opacity(0.05))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
            } else {
                settingsSection("Flow Detection") {
                    flowDetectionLockedPrompt
                }
            }
        }
    }

    /// Shown in place of the sensitivity slider + Flow Check when the
    /// user is in Simple timer mode. Explains why those controls are
    /// hidden, and offers a one-tap shortcut to switch to Smart (which
    /// surfaces the IM permission flow if needed).
    private var flowDetectionLockedPrompt: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
                Text("Flow sensitivity is a Smart-mode feature")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)
            }

            Text("You're in Simple timer mode — Blink runs a fixed 20-minute timer without reading your input, so there's no flow signal to tune. Switch to Smart to bring this back.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                UIActionLogger.buttonTapped("Switch to Smart (from Flow lock prompt)")
                appState.setDetectionMode(smart: true)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Switch to Smart mode")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(theme.textOnAccent(for: colorScheme))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(accentColor)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
            .padding(.top, 2)
        }
    }
    
    // MARK: - About
    
    private var aboutContent: some View {
        // `frame(maxWidth: .infinity, maxHeight: .infinity)` so the About
        // tab fills the same window area as the other tabs (General,
        // Theme, Flow). Without this the VStack only takes its intrinsic
        // narrow width, and the tab-switch transition animates the
        // content "expanding" as the view bounds re-flow.
        VStack(spacing: 16) {
            Spacer()

            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(theme.backgroundTop)
                    .frame(width: 80, height: 80)
                Image(theme.iconAsset)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 86, height: 86)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .frame(width: 76, height: 76)
                    .clipped()
            }
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            
            Text("Blink")
                .font(.system(size: 22, weight: .bold, design: .rounded))
            
            Text("Smart 20-20-20 Break Reminder")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            
            Text("v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.2.0")")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)

            Spacer()

            VStack(spacing: 6) {
                Text("ACKNOWLEDGMENTS")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.tertiary)
                Text(try! AttributedString(
                    markdown: "Break-end chime “Ding” by [Aiwha](https://freesound.org/people/Aiwha/sounds/196106/) · [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/)"
                ))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .tint(accentColor)
            }
            .padding(.bottom, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Detection Mode Picker

    /// Two-card picker — Smart mode vs Simple timer mode. Reads from
    /// `appState.hasInputMonitoringPermission`, writes through
    /// `appState.setDetectionMode(smart:)` so the hot-swap path handles
    /// the teardown/restart cycle (and triggers the IM permission flow
    /// if the user picks Smart without a grant).
    private var detectionModePicker: some View {
        HStack(spacing: 10) {
            detectionModeCard(
                title: "Smart",
                subtitle: "Flow-aware",
                icon: "sparkles",
                isSelected: appState.hasInputMonitoringPermission,
                action: {
                    UIActionLogger.settingChanged("detectionMode", value: "smart")
                    appState.setDetectionMode(smart: true)
                }
            )
            detectionModeCard(
                title: "Simple",
                subtitle: "Fixed timer",
                icon: "hourglass",
                isSelected: !appState.hasInputMonitoringPermission,
                action: {
                    UIActionLogger.settingChanged("detectionMode", value: "simple")
                    appState.setDetectionMode(smart: false)
                }
            )
        }
    }

    private func detectionModeCard(title: String, subtitle: String, icon: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(isSelected ? accentColor : .secondary)
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isSelected ? .primary : .secondary)
                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? accentColor.opacity(0.12) : Color.primary.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? accentColor : Color.clear, lineWidth: 1.5)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Reusable Components
    
    private func settingsSection(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(accentColor)
                .padding(.leading, 4)
            
            VStack(alignment: .leading, spacing: 12) {
                content()
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }
    
    private func settingsRow(_ label: String, @ViewBuilder content: () -> some View) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.system(size: 15))
                .padding(.top, 4)
            Spacer()
            content()
        }
    }

    private func settingsToggle(_ label: String, isOn: Binding<Bool>) -> some View {
        Toggle(label, isOn: isOn)
            .font(.system(size: 15))
            .toggleStyle(ThemedToggleStyle(theme: theme))
    }

    /// Toggle with a leading icon column. `icon` can be any View — an
    /// SF Symbol via `Image(systemName:)` or a hand-rolled SwiftUI icon
    /// (see `SettingIcons.swift`). The icon column is a fixed 32pt wide
    /// so labels align across rows regardless of glyph aspect.
    private func settingsToggleWithIcon<Icon: View>(
        _ label: String,
        @ViewBuilder icon: () -> Icon,
        isOn: Binding<Bool>
    ) -> some View {
        HStack(spacing: 10) {
            icon()
                .frame(width: 32, alignment: .center)
            Toggle(label, isOn: isOn)
                .font(.system(size: 15))
                .toggleStyle(ThemedToggleStyle(theme: theme))
        }
    }

    /// Convenience for the common SF Symbol case — keeps call sites short.
    private func settingsToggleWithIcon(
        _ label: String,
        systemImage: String,
        isOn: Binding<Bool>
    ) -> some View {
        settingsToggleWithIcon(label, icon: {
            Image(systemName: systemImage)
                .font(.system(size: 17))
                .foregroundStyle(accentColor)
                .symbolRenderingMode(.hierarchical)
        }, isOn: isOn)
    }

    /// Caption text shown under toggles / rows. Sized + colored for
    /// readability — the previous combination (`size: 11` +
    /// `.tertiary`) was painful to read on white backgrounds, and the
    /// user flagged it specifically.
    private func settingsCaption(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13))
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            // 42pt = 32pt icon column + 10pt spacing. Captions sit under
            // iconified toggles and align with the toggle's label, not
            // the icon. The General tab now uses icons on every row, so
            // captions get the same indent uniformly.
            .padding(.leading, 42)
    }
    
    private func stateRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .medium, design: .monospaced))
        }
    }
    
    private func updateLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("[Blink] Launch at login error: \(error)")
        }
    }
}

#Preview("Settings - General (Smart)") {
    SettingsView(appState: AppState(preview: true))
        .environmentObject(ThemeManager.shared)
}

// Tabs are 0=General, 1=Theme, 2=Flow, 3=About.
// AppState(preview: true) hard-codes hasInputMonitoringPermission=true,
// so the Flow tab renders its full sensitivity slider + Flow Check by
// default. To see the Simple-mode locked-Flow prompt, the previews
// below flip the flag and land directly on the Flow tab.

#Preview("Settings - Flow tab (Smart)") {
    SettingsView(appState: AppState(preview: true), initialTab: 2)
        .environmentObject(ThemeManager.shared)
}

#Preview("Settings - Flow tab (Simple, locked)") {
    UserDefaults.standard.set(true, forKey: "basicModeOptIn")
    let state = AppState(preview: true)
    state.hasInputMonitoringPermission = false
    return SettingsView(appState: state, initialTab: 2)
        .environmentObject(ThemeManager.shared)
}

#Preview("Settings - Flow tab (missing IM permission)") {
    UserDefaults.standard.set(false, forKey: "basicModeOptIn")
    let state = AppState(preview: true)
    state.hasInputMonitoringPermission = false
    return SettingsView(appState: state, initialTab: 2)
        .environmentObject(ThemeManager.shared)
}
