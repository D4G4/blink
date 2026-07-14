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
    @AppStorage("currentAppGraceMinutes") private var currentAppGraceMinutes: Double = 5
    @AppStorage("pauseDuringCalendarEvents") private var pauseDuringCalendarEvents: Bool = false
    @AppStorage("suggestUnlinkedEvents") private var suggestUnlinkedEvents: Bool = true
    @AppStorage("chimeEnabled") private var chimeEnabled: Bool = true
    @AppStorage("chimeID") private var chimeID: String = ChimePlayer.defaultChimeID
    @AppStorage("chimeVolume") private var chimeVolume: Double = ChimePlayer.defaultVolume
    @AppStorage("breakSuggestionsEnabled") private var breakSuggestionsEnabled: Bool = true
    @AppStorage(BlinkUpdater.betaChannelKey) private var betaChannelEnabled: Bool = false

    @State private var showSuggestionsHelp: Bool = false
    @State private var debugExpanded: Bool = false

    /// Sentinel value for the "None" entry in the chime picker. Selecting it
    /// flips `chimeEnabled` to false; selecting any real chime flips it true
    /// AND fires a preview so the user hears what they picked. Stored
    /// separately from `chimeID` so toggling None then back to the previous
    /// chime preserves the prior selection.
    static let noneChimeTag: String = "__none__"

    /// Bridges the picker (which is a single `String` selection across
    /// None + real chimes) to the two underlying defaults
    /// (`chimeEnabled` + `chimeID`). On set: None disables, anything else
    /// enables and previews.
    private var chimeSelection: Binding<String> {
        Binding(
            get: { chimeEnabled ? chimeID : Self.noneChimeTag },
            set: { newValue in
                if newValue == Self.noneChimeTag {
                    chimeEnabled = false
                } else {
                    chimeEnabled = true
                    chimeID = newValue
                    UIActionLogger.settingChanged("chimeID", value: newValue)
                    ChimePlayer.shared.play(id: newValue, volume: chimeVolume)
                }
            }
        )
    }
    
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
                settingsItem {
                    settingsToggleWithIcon(
                        "Show countdown timer",
                        icon: {
                            CountdownTimerIcon(accent: accentColor, foreground: .primary)
                        },
                        isOn: $showTimerInMenuBar
                    )
                }
            }

            settingsSection("Break Screen") {
                settingsItem {
                    settingsToggleWithIcon(
                        "Use dark overlay",
                        icon: {
                            DarkOverlayIcon(accent: accentColor, foreground: .primary)
                        },
                        isOn: $useDarkOverlay
                    )
                    settingsCaption("Pure black background instead of themed colors")
                }

                settingsItem {
                    SmartSuggestionsSettingControls(
                        theme: theme,
                        accentColor: accentColor,
                        isOn: $breakSuggestionsEnabled,
                        showHelp: $showSuggestionsHelp
                    )
                }
            }

            settingsSection("Break-End Chime") {
                settingsItem {
                    // The picker IS the on/off control — "None" disables,
                    // any real chime enables AND auto-previews on selection.
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 10) {
                            Image(systemName: "bell.fill")
                                .font(.system(size: 17))
                                .foregroundStyle(accentColor)
                                .symbolRenderingMode(.hierarchical)
                                .frame(width: 32, alignment: .center)
                            Text("Sound")
                                .font(.system(size: 15))
                            Spacer()
                            Picker("", selection: chimeSelection) {
                                Text("None").tag(Self.noneChimeTag)
                                ForEach(ChimePlayer.Chime.all) { chime in
                                    Text(chime.displayName).tag(chime.id)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 150)
                        }
                        if chimeEnabled {
                            HStack(spacing: 10) {
                                // Empty 32pt column so Volume aligns with "Sound" above.
                                Color.clear.frame(width: 32)
                                Text("Volume")
                                    .font(.system(size: 15))
                                Slider(value: $chimeVolume, in: 0...1)
                                    .tint(accentColor)
                                Text("\(Int(chimeVolume * 100))%")
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 36, alignment: .trailing)
                            }
                        }
                    }
                }
            }

            settingsSection("Pause") {
                settingsItem {
                    // Grace window before a "pause while <App> is open" pause
                    // auto-resumes after you leave the app — so brief tab/app
                    // switches during a meeting don't bounce breaks back on.
                    HStack(spacing: 10) {
                        Image(systemName: "hourglass")
                            .font(.system(size: 17))
                            .foregroundStyle(accentColor)
                            .symbolRenderingMode(.hierarchical)
                            .frame(width: 32, alignment: .center)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Resume after leaving app")
                                .font(.system(size: 15))
                            Text("Grace before a per-app pause ends")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: $currentAppGraceMinutes, in: 0...30, step: 1)
                            .tint(accentColor)
                        Text(currentAppGraceMinutes == 0 ? "Off" : "\(Int(currentAppGraceMinutes)) min")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .frame(width: 50, alignment: .trailing)
                    }
                }
            }

            settingsSection("Mic Detection") {
                settingsItem {
                    settingsToggleWithIcon("Pause timer during calls", systemImage: "mic.fill", isOn: $pauseDuringCalls)
                    settingsCaption("Pauses breaks when your mic is active. Turn off if you use Dictation or Siri — they keep the mic open and will pause Blink permanently.")
                }
            }

            settingsSection("Calendar") {
                settingsItem {
                    settingsToggleWithIcon("Pause during meetings", systemImage: "calendar", isOn: $pauseDuringCalendarEvents)
                        .onChange(of: pauseDuringCalendarEvents) { _, newValue in
                            UIActionLogger.settingChanged("pauseDuringCalendarEvents", value: "\(newValue)")
                            appState.setCalendarIntegration(enabled: newValue)
                        }
                    settingsCaption("Auto-pauses breaks during calendar events that have a meeting link (Zoom, Meet, Teams). Blink reads your calendar only to detect meeting times.")
                }
                if pauseDuringCalendarEvents {
                    settingsItem {
                        settingsToggleWithIcon("Suggest pause for other events", systemImage: "bell.badge", isOn: $suggestUnlinkedEvents)
                        settingsCaption("For events without a meeting link, show a dismissible pause suggestion instead of pausing automatically.")
                    }
                }
            }

            settingsSection("Timer") {
                settingsItem {
                // Hand-rolled HStack instead of settingsRow because
                // settingsRow uses .top alignment with a 4pt label inset,
                // which mis-aligned the clock icon, "Base interval" label,
                // and the slider relative to each other. Plain .center
                // HStack lines everything up on its midpoint.
                HStack(spacing: 10) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 17))
                        .foregroundStyle(accentColor)
                        .symbolRenderingMode(.hierarchical)
                        .frame(width: 32, alignment: .center)
                    Text("Base interval")
                        .font(.system(size: 15))
                    Slider(value: $baseInterval, in: 10...45, step: 5)
                        .tint(accentColor)
                    Text("\(Int(baseInterval)) min")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(width: 50, alignment: .trailing)
                }
                }
            }

            settingsSection("System") {
                settingsItem {
                    settingsToggleWithIcon("Launch at login", systemImage: "power.circle.fill", isOn: $launchAtLogin)
                        .onChange(of: launchAtLogin) { _, newValue in
                            UIActionLogger.settingChanged("launchAtLogin", value: "\(newValue)")
                            updateLaunchAtLogin(newValue)
                        }
                }

                settingsItem {
                    settingsToggleWithIcon("Receive beta updates", systemImage: "flask.fill", isOn: $betaChannelEnabled)
                    settingsCaption("Get new features before everyone else. Beta builds may be less stable; you can switch off any time to roll back to the next stable release.")
                }

                // Check for Updates as a primary call-to-action — full
                // width, accent-coloured, more discoverable than the
                // previous flat link.
                Button {
                    UIActionLogger.buttonTapped("Check for Updates")
                    BlinkUpdater.shared.checkForUpdates()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 13, weight: .medium))
                        Text("Check for Updates")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(theme.textOnAccent(for: colorScheme))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(accentColor)
                    )
                }
                .buttonStyle(.plain)
                .padding(.top, 2)

                // Debug section — collapsible. Houses the dev/diagnostic
                // controls (toast notifications, log files, onboarding
                // reset) that most users won't touch. Defaults collapsed
                // so the bottom of the General tab stays clean.
                debugDisclosure
            }
        }
    }

    // MARK: - Debug disclosure (System section)

    /// Collapsible "Debug" group at the bottom of System. Houses the
    /// diagnostic controls (debug toasts, log files, onboarding reset)
    /// most users never touch. Defaults closed so the General tab's
    /// foot stays clean.
    private var debugDisclosure: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.easeInOut(duration: 0.18)) {
                    debugExpanded.toggle()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(debugExpanded ? 90 : 0))
                    Text("Debug")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.leading, 4)
            .padding(.top, 6)

            if debugExpanded {
                settingsItem {
                    settingsToggleWithIcon("Debug notifications", systemImage: "ant.fill", isOn: $appState.debugNotifications)
                    settingsCaption("Show toasts for timer resets, state changes, and idle detection")
                }

                debugActionButton(label: "Restart Onboarding", systemImage: "arrow.counterclockwise") {
                    UIActionLogger.buttonTapped("Restart Onboarding")
                    themeManager.hasCompletedOnboarding = false
                    let path = Bundle.main.bundleURL.absoluteString
                    let task = Process()
                    task.launchPath = "/usr/bin/open"
                    task.arguments = [path]
                    task.launch()
                    NSApp.terminate(nil)
                }

                debugActionButton(label: "Open Log Files", systemImage: "folder") {
                    UIActionLogger.buttonTapped("Open Log Files")
                    LogExporter.revealInFinder()
                }
            }
        }
    }

    /// Secondary-style button used for Restart Onboarding + Open Log Files
    /// inside the debug disclosure. Lower visual weight than the primary
    /// Check for Updates button above the disclosure, matching their
    /// diagnostic-utility role.
    private func debugActionButton(label: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.system(size: 12))
                Text(label)
                    .font(.system(size: 13))
                Spacer()
            }
            .foregroundStyle(accentColor)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.secondary.opacity(0.06))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
        // Title outside the card group. Inner VStack collects per-setting
        // cards (one per `settingsItem` call) so each setting gets its
        // own visual container — easier to scan than a single card
        // lumping several unrelated toggles together. Spacing 8pt
        // between cards is tight enough to read as "same section" but
        // open enough that each item feels distinct.
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(accentColor)
                .padding(.leading, 4)

            VStack(alignment: .leading, spacing: 8) {
                content()
            }
        }
    }

    /// Wraps a single setting's controls (toggle + optional caption +
    /// optional Learn more) in a subtle card. Sections that show
    /// multiple unrelated settings call this once per setting so each
    /// gets its own card; action links that shouldn't read as
    /// settings (Check for Updates, Restart Onboarding) skip this and
    /// sit flat.
    private func settingsItem<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            content()
        }
        // 12pt horizontal breathing room so icons (especially the
        // hand-rolled CountdownTimerIcon / DarkOverlayIcon that fill
        // their 32pt frame) aren't flush against the card edge, and the
        // toggle on the right side has room before the trailing edge.
        // Intentionally breaks the title↔icon left alignment — title
        // stays at .leading(4) on the section, content sits 8pt inward.
        .padding(.horizontal, 12)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.secondary.opacity(0.06))
        )
    }

    /// Variant with the icon at the outer level — it sits in its own
    /// 32pt-wide leading column, vertically centered with the entire
    /// content VStack. Use when a row has both a toggle AND a caption
    /// (and maybe more): the previous pattern locked the icon next to
    /// the toggle via `settingsToggleWithIcon`, leaving the icon at the
    /// top edge while the caption hung below it. With the icon at this
    /// level, it centers between the top of the toggle and the bottom
    /// of the caption automatically.
    private func settingsItem<Icon: View, Content: View>(
        @ViewBuilder icon: () -> Icon,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(alignment: .center, spacing: 10) {
            icon()
                .frame(width: 32, alignment: .center)
            VStack(alignment: .leading, spacing: 6) {
                content()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.secondary.opacity(0.06))
        )
    }

    /// Caption styled for use inside an outer-icon settingsItem. No
    /// leading indent — the parent HStack's icon column already shifts
    /// the content VStack to the right of the icon, so the caption
    /// naturally sits under the toggle label.
    private func settingsCaptionFlat(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13))
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
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
