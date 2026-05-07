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
                .environmentObject(UpdateChecker.shared)
        } label: {
            if showTimerInMenuBar && appState.hasAccessibilityPermission {
                HStack(spacing: 4) {
                    menuBarIcon
                    Text(appState.formattedRemaining)
                        .monospacedDigit()
                }
            } else {
                menuBarIcon
            }
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
        let themeManager = ThemeManager.shared
        if !themeManager.hasCompletedOnboarding {
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)

            onboardingController = OnboardingWindowController()
            onboardingController?.show(themeManager: themeManager) { [weak self] in
                self?.onboardingController = nil
                NSApp.setActivationPolicy(.accessory)
                NotificationCenter.default.post(name: .onboardingCompleted, object: nil)
            }
        } else {
            NSApp.setActivationPolicy(.accessory)
            UpdateChecker.shared.checkForUpdate()
        }
    }
}
