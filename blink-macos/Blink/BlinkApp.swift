import SwiftUI

@main
struct BlinkApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState()
    @StateObject private var themeManager = ThemeManager.shared
    @AppStorage("showTimerInMenuBar") private var showTimerInMenuBar: Bool = false

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(appState: appState)
                .environmentObject(themeManager)
        } label: {
            Group {
                if showTimerInMenuBar && appState.hasInputMonitoringPermission {
                    HStack(spacing: 4) {
                        menuBarIcon
                        ZStack(alignment: .trailing) {
                            Text("00:00")
                                .monospacedDigit()
                                .hidden()
                            Text(appState.formattedRemaining)
                                .monospacedDigit()
                        }
                    }
                } else {
                    menuBarIcon
                }
            }
            .opacity(appState.isPaused ? 0.35 : 1.0)
        }
        .menuBarExtraStyle(.window)
    }

    private var menuBarIcon: some View {
        Image(themeManager.current.menuBarIconAsset)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 18, height: 18)
    }
}

extension Notification.Name {
    static let onboardingCompleted = Notification.Name("BlinkOnboardingCompleted")
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var onboardingController: OnboardingWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        UserDefaults.standard.register(defaults: [
            "pauseDuringCalls": true,
        ])
        let themeManager = ThemeManager.shared
        if !themeManager.hasCompletedOnboarding {
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)

            onboardingController = OnboardingWindowController()
            onboardingController?.show(themeManager: themeManager) { [weak self] in
                self?.onboardingController = nil
                NSApp.setActivationPolicy(.accessory)
                // Onboarding (theme + flow sensitivity) is done. AppState
                // decides what to do next — if IM is already granted,
                // start the engine; otherwise show PermissionFlowWindow.
                NotificationCenter.default.post(name: .onboardingCompleted, object: nil)
            }
        } else {
            NSApp.setActivationPolicy(.accessory)
        }
        // Instantiate the updater so Sparkle's scheduled-check loop and
        // SUEnableAutomaticChecks=YES take effect from launch. The
        // singleton holds the SPUStandardUpdaterController for the
        // lifetime of the app.
        _ = BlinkUpdater.shared
        // Sparkle's stock behaviour is to wait until the next scheduled
        // interval (24h since SULastCheckTime) before background-checking.
        // For a menu bar app that gets relaunched after sleep/reboot/quit,
        // the user expectation is "check now, I just opened it." Fire a
        // silent background check ~15s post-launch so any pending update
        // surfaces promptly without competing with launch UI.
        BlinkUpdater.shared.checkForUpdatesInBackgroundAfterLaunchSettle()
    }

    /// Dock-icon click recovery. Blink's onboarding / detection-mode choice /
    /// permission / recovery surfaces are non-dismissible setup windows. They
    /// have a Dock icon (their flows set activation policy to .regular), but if
    /// one gets buried behind another app, clicking the Dock icon should raise
    /// it. Re-front any open window tagged `.blinkSetupWindow`.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        let surfaced = sender.windows.filter { $0.identifier == .blinkSetupWindow && $0.isVisible }
        for window in surfaced {
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
        }
        if !surfaced.isEmpty {
            NSApp.activate()
        }
        return true
    }
}
