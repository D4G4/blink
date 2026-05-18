import SwiftUI
import ServiceManagement
import BlinkCore

struct SettingsView: View {
    @ObservedObject var appState: AppState
    @EnvironmentObject var themeManager: ThemeManager
    @AppStorage("baseInterval") private var baseInterval: Double = 20
    @AppStorage("flowSensitivity") private var flowSensitivity: Double = 0.7
    @AppStorage("launchAtLogin") private var launchAtLogin: Bool = false
    @AppStorage("showTimerInMenuBar") private var showTimerInMenuBar: Bool = false
    @AppStorage("useDarkOverlay") private var useDarkOverlay: Bool = false
    @AppStorage("pauseDuringCalls") private var pauseDuringCalls: Bool = true
    
    @Environment(\.colorScheme) private var colorScheme
    private var theme: BlinkTheme { themeManager.current }
    private var accentColor: Color { theme.accent(for: colorScheme) }
    
    @State private var selectedTab: Int = 0
    
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
        .frame(width: 440, height: 440)
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
            settingsSection("Mic Detection") {
                settingsToggle("Pause timer during calls", isOn: $pauseDuringCalls)
                Text("Pauses breaks when your mic is active. Turn off if you use Dictation or Siri — they keep the mic open and will pause Blink permanently.")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .padding(.leading, 4)
            }
            
            settingsSection("Timer") {
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
            
            settingsSection("Menu Bar") {
                settingsToggle("Show countdown timer", isOn: $showTimerInMenuBar)
            }
            
            settingsSection("Break Screen") {
                settingsToggle("Use dark overlay", isOn: $useDarkOverlay)
                Text("Pure black background instead of themed colors")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .padding(.leading, 4)
            }
            
            settingsSection("System") {
                settingsToggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        UIActionLogger.settingChanged("launchAtLogin", value: "\(newValue)")
                        updateLaunchAtLogin(newValue)
                    }
                
                settingsToggle("Debug notifications", isOn: $appState.debugNotifications)
                Text("Show toasts for timer resets, state changes, and idle detection")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .padding(.leading, 4)
                
                settingsRow("Accessibility") {
                    if appState.hasAccessibilityPermission {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .font(.system(size: 13))
                            Text("Granted")
                                .font(.system(size: 12))
                                .foregroundStyle(.green)
                        }
                    } else {
                        Button("Grant") {
                            UIActionLogger.buttonTapped("Grant Accessibility")
                            PermissionManager.openAccessibilitySettings()
                        }
                        .font(.system(size: 12))
                        .buttonStyle(.borderedProminent)
                        .tint(accentColor)
                        .controlSize(.small)
                    }
                }
                
                if !UpdateChecker.isAppStore {
                    HStack(spacing: 8) {
                        Button {
                            UIActionLogger.buttonTapped("Check for Updates")
                            UpdateChecker.shared.checkForUpdate()
                        } label: {
                            HStack(spacing: 4) {
                                if UpdateChecker.shared.isChecking {
                                    ProgressView()
                                        .controlSize(.small)
                                        .scaleEffect(0.7)
                                } else {
                                    Image(systemName: "arrow.triangle.2.circlepath")
                                        .font(.system(size: 11))
                                }
                                Text("Check for Updates")
                                    .font(.system(size: 12))
                            }
                            .foregroundStyle(accentColor)
                        }
                        .buttonStyle(.plain)
                        .disabled(UpdateChecker.shared.isChecking)
                        
                        if let result = UpdateChecker.shared.lastCheckResult {
                            switch result {
                            case .upToDate:
                                Text("You're up to date")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            case .available(let version):
                                Text("v\(version) available")
                                    .font(.system(size: 11))
                                    .foregroundStyle(accentColor)
                            case .failed:
                                Text("Check failed")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.red)
                            }
                        }
                    }
                    .padding(.top, 4)
                }
                
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
    
    private var flowContent: some View {
        VStack(alignment: .leading, spacing: 20) {
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
        }
    }
    
    // MARK: - About
    
    private var aboutContent: some View {
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
        }
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
                .font(.system(size: 13))
                .padding(.top, 4)
            Spacer()
            content()
        }
    }
    
    private func settingsToggle(_ label: String, isOn: Binding<Bool>) -> some View {
        Toggle(label, isOn: isOn)
            .font(.system(size: 13))
            .toggleStyle(ThemedToggleStyle(theme: theme))
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

#Preview {
    SettingsView(appState: AppState(preview: true))
        .environmentObject(ThemeManager.shared)
}
