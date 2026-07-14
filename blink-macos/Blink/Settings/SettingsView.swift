import SwiftUI
import ServiceManagement
import BlinkCore

// MARK: - Sidebar category

/// The System-Settings-style sidebar splits what used to be one overloaded
/// "General" scroll into focused panes. Raw values are stable so deep-links
/// (What's New cards, menu bar "Tap to change") can map onto them.
enum SettingsCategory: Int, CaseIterable, Identifiable {
    case general, appearance, breaks, focus, autoPause, about

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .general:    return "General"
        case .appearance: return "Appearance"
        case .breaks:     return "Breaks"
        case .focus:      return "Focus"
        case .autoPause:  return "Auto-Pause"
        case .about:      return "About"
        }
    }

    var symbol: String {
        switch self {
        case .general:    return "gearshape.fill"
        case .appearance: return "paintbrush.fill"
        case .breaks:     return "eye.fill"
        case .focus:      return "sparkles"
        case .autoPause:  return "pause.circle.fill"
        case .about:      return "info.circle.fill"
        }
    }

    /// System-Settings-style fixed tile colors — semantic, theme-independent,
    /// so the sidebar reads as distinct rows regardless of the app accent.
    var tint: Color {
        switch self {
        case .general:    return Color(red: 0.56, green: 0.56, blue: 0.58) // gray
        case .appearance: return Color(red: 0.96, green: 0.34, blue: 0.55) // pink
        case .breaks:     return Color(red: 0.18, green: 0.72, blue: 0.62) // teal
        case .focus:      return Color(red: 0.60, green: 0.40, blue: 0.92) // purple
        case .autoPause:  return Color(red: 0.98, green: 0.58, blue: 0.20) // orange
        case .about:      return Color(red: 0.20, green: 0.55, blue: 0.96) // blue
        }
    }
}

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

    @State private var selectedCategory: SettingsCategory

    /// Optional section anchor to scroll to + briefly highlight on open, so a
    /// deep-link (What's New card / discoverability tip) lands the user on the
    /// exact setting inside its pane instead of just the top of the pane.
    private let scrollTarget: String?
    /// The anchor currently flashing its highlight (cleared after ~2s).
    @State private var highlightedAnchor: String?

    /// Preserves the historical `(initialTab, scrollTo)` deep-link contract so
    /// every existing caller keeps working unchanged. `scrollTo` (calendar /
    /// pause) always lands on Auto-Pause; otherwise the legacy tab index maps:
    /// 0=General, 1=Theme→Appearance, 2=Flow→Focus, 3=About.
    init(appState: AppState, initialTab: Int = 0, scrollTo: String? = nil) {
        self.appState = appState
        self.scrollTarget = scrollTo

        let category: SettingsCategory
        if scrollTo == SettingsAnchor.calendar || scrollTo == SettingsAnchor.pause {
            category = .autoPause
        } else {
            switch initialTab {
            case 1:  category = .appearance
            case 2:  category = .focus
            case 3:  category = .about
            default: category = .general
            }
        }
        self._selectedCategory = State(initialValue: category)
    }

    /// Direct-category initializer for previews and snapshot tests — the
    /// public `initialTab`/`scrollTo` init has no deep-link onto Breaks, so
    /// per-pane coverage needs a way to land on any category.
    init(appState: AppState, category: SettingsCategory) {
        self.appState = appState
        self.scrollTarget = nil
        self._selectedCategory = State(initialValue: category)
    }

    var body: some View {
        HStack(spacing: 0) {
            sidebar
                .frame(width: 200)

            Divider()

            detail
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 700, minHeight: 480)
        .tint(accentColor)
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        List(selection: $selectedCategory) {
            ForEach(SettingsCategory.allCases) { category in
                Label {
                    Text(category.title)
                        .font(.system(size: 13))
                } icon: {
                    sidebarIcon(category.symbol, category.tint)
                }
                .tag(category)
            }
        }
        .listStyle(.sidebar)
    }

    /// System-Settings-style icon tile: a white SF Symbol on a rounded,
    /// color-filled square.
    private func sidebarIcon(_ symbol: String, _ color: Color) -> some View {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(color)
            .frame(width: 22, height: 22)
            .overlay(
                Image(systemName: symbol)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
            )
    }

    // MARK: - Detail pane

    private var detail: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    paneHeader
                    paneContent
                }
                .padding(.horizontal, 26)
                .padding(.vertical, 24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .onAppear { scrollToTargetIfNeeded(proxy) }
        }
        .background(Color(nsColor: .textBackgroundColor).opacity(0.4))
    }

    /// Big colored icon + title at the top of each pane — mirrors the header
    /// System Settings puts above every section.
    private var paneHeader: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(selectedCategory.tint)
                .frame(width: 40, height: 40)
                .overlay(
                    Image(systemName: selectedCategory.symbol)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                )
            Text(selectedCategory.title)
                .font(.system(size: 22, weight: .bold))
            Spacer()
        }
    }

    @ViewBuilder
    private var paneContent: some View {
        switch selectedCategory {
        case .general:    generalPane
        case .appearance: appearancePane
        case .breaks:     breaksPane
        case .focus:      focusPane
        case .autoPause:  autoPausePane
        case .about:      aboutPane
        }
    }

    /// Scroll to the deep-link target (if any) shortly after the window
    /// appears, then flash a highlight on it for a couple of seconds so the
    /// user's eye lands on the right setting inside the pane.
    private func scrollToTargetIfNeeded(_ proxy: ScrollViewProxy) {
        guard let target = scrollTarget else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            withAnimation(.easeInOut(duration: 0.35)) {
                proxy.scrollTo(target, anchor: .top)
            }
            withAnimation(.easeInOut(duration: 0.3)) { highlightedAnchor = target }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
                withAnimation(.easeInOut(duration: 0.5)) { highlightedAnchor = nil }
            }
        }
    }

    private func deepLinkHighlight(_ anchor: String) -> some ViewModifier {
        DeepLinkHighlight(isActive: highlightedAnchor == anchor, accent: accentColor)
    }

    // MARK: - General pane

    private var generalPane: some View {
        VStack(alignment: .leading, spacing: 20) {
            if let recent = appState.recentlyUpdatedVersion {
                whatsNewCard(version: recent)
            }

            settingsSection("Startup") {
                settingsItem {
                    settingsToggleWithIcon("Launch at login", systemImage: "power.circle.fill", isOn: $launchAtLogin)
                        .onChange(of: launchAtLogin) { _, newValue in
                            UIActionLogger.settingChanged("launchAtLogin", value: "\(newValue)")
                            updateLaunchAtLogin(newValue)
                        }
                }
            }

            settingsSection("Menu Bar") {
                settingsItem {
                    settingsToggleWithIcon(
                        "Show countdown timer",
                        icon: { CountdownTimerIcon(accent: accentColor, foreground: .primary) },
                        isOn: $showTimerInMenuBar
                    )
                }
            }

            settingsSection("Updates") {
                settingsItem {
                    settingsToggleWithIcon("Receive beta updates", systemImage: "flask.fill", isOn: $betaChannelEnabled)
                    settingsCaption("New features early. Beta builds may be less stable.")
                }

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
                    .background(RoundedRectangle(cornerRadius: 10).fill(accentColor))
                }
                .buttonStyle(.plain)
                .padding(.top, 2)
            }
        }
    }

    /// "What's New" entry point — lives at the top of General for 10 days
    /// after an update (gated by `AppState.recentlyUpdatedVersion`). Re-opens
    /// the release digest so users who dismissed the launch window can still
    /// find it. Beta suffix stripped for a clean "v5.2.0".
    private func whatsNewCard(version: String) -> some View {
        let display = version.split(separator: "-").first.map(String.init) ?? version
        return settingsSection("What's New") {
            Button {
                UIActionLogger.buttonTapped("What's New (Settings)")
                appState.showWhatsNewFromSettings()
            } label: {
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(accentColor)
                        .frame(width: 32, height: 32)
                        .overlay(
                            Image(systemName: "gift.fill")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(theme.textOnAccent(for: colorScheme))
                        )
                    VStack(alignment: .leading, spacing: 1) {
                        Text("See what's new in v\(display)")
                            .font(.system(size: 15))
                            .foregroundStyle(.primary)
                        Text("Recent updates and features")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("NEW")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(theme.textOnAccent(for: colorScheme))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(accentColor))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 10).fill(accentColor.opacity(0.08)))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Appearance pane

    private var appearancePane: some View {
        VStack(alignment: .leading, spacing: 20) {
            settingsSection("Theme") {
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
                            withAnimation(.easeInOut(duration: 0.2)) { themeManager.select(t) }
                        }
                    }
                }
                .padding(.vertical, 4)
            }

            settingsSection("Break Screen") {
                settingsItem {
                    settingsToggleWithIcon(
                        "Use dark overlay",
                        icon: { DarkOverlayIcon(accent: accentColor, foreground: .primary) },
                        isOn: $useDarkOverlay
                    )
                    settingsCaption("Pure black background instead of themed colors.")
                }
            }
        }
    }

    // MARK: - Breaks pane

    private var breaksPane: some View {
        VStack(alignment: .leading, spacing: 20) {
            settingsSection("Timing") {
                settingsItem {
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

            settingsSection("Suggestions") {
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
        }
    }

    // MARK: - Focus pane

    @State private var flowCheckDetail: String?

    private var focusPane: some View {
        VStack(alignment: .leading, spacing: 20) {
            settingsSection("Detection Mode") {
                detectionModePicker
                settingsCaption(appState.hasInputMonitoringPermission
                    ? "Smart reads typing and mouse activity (via Input Monitoring) so breaks land at natural pauses. Simple is a fixed 20-minute timer needing no permissions."
                    : "Simple runs a fixed 20-minute timer with no permissions. Switch to Smart for flow-aware timing.")
            }

            // Sensitivity + Flow Check are only meaningful in Smart mode.
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
    /// user is in Simple timer mode.
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

            Text("You're in Simple timer mode, so there's no flow signal to tune. Switch to Smart to bring this back.")
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

    // MARK: - Auto-Pause pane

    private var autoPausePane: some View {
        VStack(alignment: .leading, spacing: 20) {
            settingsSection("Microphone") {
                settingsItem {
                    settingsToggleWithIcon("Pause timer during calls", systemImage: "mic.fill", isOn: $pauseDuringCalls)
                    settingsCaption("Pauses breaks when your mic is active. Turn off if you use Dictation or Siri — they hold the mic open.")
                }
            }

            settingsSection("Calendar") {
                settingsItem {
                    settingsToggleWithIcon("Pause during meetings", systemImage: "calendar", isOn: $pauseDuringCalendarEvents)
                        .onChange(of: pauseDuringCalendarEvents) { _, newValue in
                            UIActionLogger.settingChanged("pauseDuringCalendarEvents", value: "\(newValue)")
                            appState.setCalendarIntegration(enabled: newValue)
                        }
                    settingsCaption("Auto-pauses during events with a meeting link (Zoom, Meet, Teams). Blink reads your calendar only to detect meeting times.")
                }
                if pauseDuringCalendarEvents {
                    settingsItem {
                        settingsToggleWithIcon("Suggest pause for other events", systemImage: "bell.badge", isOn: $suggestUnlinkedEvents)
                        settingsCaption("For events without a link, show a dismissible suggestion instead of pausing.")
                    }
                }
            }
            .modifier(deepLinkHighlight(SettingsAnchor.calendar))
            .id(SettingsAnchor.calendar)

            settingsSection("Per-App Pause") {
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
            .modifier(deepLinkHighlight(SettingsAnchor.pause))
            .id(SettingsAnchor.pause)
        }
    }

    // MARK: - About pane

    private var aboutPane: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(theme.backgroundTop)
                        .frame(width: 72, height: 72)
                    Image(theme.iconAsset)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 78, height: 78)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .frame(width: 68, height: 68)
                        .clipped()
                }
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text("Blink")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                    Text("Smart 20-20-20 Break Reminder")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                    Text("v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.2.0")")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
                Spacer()
            }

            settingsSection("Acknowledgments") {
                Text(try! AttributedString(
                    markdown: "Break-end chime “Ding” by [Aiwha](https://freesound.org/people/Aiwha/sounds/196106/) · [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/)"
                ))
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .tint(accentColor)
            }

            debugDisclosure
        }
    }

    // MARK: - Debug disclosure (About pane)

    /// Collapsible "Debug" group. Houses the diagnostic controls (debug
    /// toasts, log files, onboarding reset) most users never touch. Defaults
    /// closed so the About pane stays clean.
    private var debugDisclosure: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.easeInOut(duration: 0.18)) { debugExpanded.toggle() }
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
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.secondary.opacity(0.06)))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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

            VStack(alignment: .leading, spacing: 8) {
                content()
            }
        }
    }

    /// Wraps a single setting's controls (toggle + optional caption) in a
    /// subtle card. Sections with several unrelated settings call this once
    /// per setting so each gets its own container.
    private func settingsItem<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            content()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.secondary.opacity(0.06)))
    }

    /// Toggle with a leading icon column. `icon` can be any View — an
    /// SF Symbol via `Image(systemName:)` or a hand-rolled SwiftUI icon.
    /// The icon column is a fixed 32pt wide so labels align across rows.
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

    /// Caption text shown under toggles / rows. 42pt leading = 32pt icon
    /// column + 10pt spacing, so captions align with the toggle's label.
    private func settingsCaption(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13))
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.leading, 42)
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

#Preview("Settings - General") {
    SettingsView(appState: AppState(preview: true))
        .environmentObject(ThemeManager.shared)
}

#Preview("Settings - Focus (Smart)") {
    SettingsView(appState: AppState(preview: true), initialTab: 2)
        .environmentObject(ThemeManager.shared)
}

#Preview("Settings - Focus (Simple, locked)") {
    UserDefaults.standard.set(true, forKey: "basicModeOptIn")
    let state = AppState(preview: true)
    state.hasInputMonitoringPermission = false
    return SettingsView(appState: state, initialTab: 2)
        .environmentObject(ThemeManager.shared)
}

#Preview("Settings - Auto-Pause (deep-link)") {
    SettingsView(appState: AppState(preview: true), scrollTo: SettingsAnchor.calendar)
        .environmentObject(ThemeManager.shared)
}

/// A brief accent highlight for a deep-linked Settings section — a soft fill
/// plus a rounded ring that fades in and out. Uses a small REAL inset padding
/// (not an overflow) so the fill/ring stay inside the view's own frame.
private struct DeepLinkHighlight: ViewModifier {
    let isActive: Bool
    let accent: Color

    func body(content: Content) -> some View {
        content
            .padding(6)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(accent.opacity(isActive ? 0.12 : 0))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(accent.opacity(isActive ? 0.55 : 0), lineWidth: 1.5)
            )
            .animation(.easeInOut(duration: 0.4), value: isActive)
    }
}
