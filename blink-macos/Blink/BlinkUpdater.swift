import Foundation
import Sparkle

/// Thin wrapper around Sparkle's standard updater controller so the rest
/// of the app can call a single `.checkForUpdates()` method without
/// importing Sparkle at every callsite.
///
/// Sparkle is configured in Info.plist:
///   - SUFeedURL → https://blink20.net/appcast.xml
///   - SUPublicEDKey → public half of the EdDSA pair (private in Keychain)
///   - SUEnableAutomaticChecks → YES (background daily check)
///   - SUScheduledCheckInterval → 86400 (24h)
///   - SUEnableInstallerLauncherService → YES (sandbox-compatible install)
///
/// The controller is instantiated once at app launch in BlinkApp; it owns
/// the periodic background check, the user-driven menu action, and the
/// standard UI flow (notice → download → ready-to-install → relaunch).
@MainActor
final class BlinkUpdater {
    static let shared = BlinkUpdater()

    private let controller: SPUStandardUpdaterController

    private init() {
        controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
    }

    /// Trigger a user-initiated update check. Same behaviour as the
    /// First Responder action "checkForUpdates:" — shows progress, then
    /// a dialog whether updates are available or not.
    func checkForUpdates() {
        controller.checkForUpdates(nil)
    }

    /// Fire a silent background update check ~15s after launch. SPUStandardUpdaterController
    /// deliberately does NOT check on launch by default — it waits until the next
    /// scheduled tick (SUScheduledCheckInterval since SULastCheckTime). For a menu bar
    /// app that's relaunched after sleep/reboot/quit, the expected UX is "check now, my
    /// app just started" — so we explicitly trigger a background check shortly after
    /// launch. The 15s delay is to avoid competing with the launch HUD animation,
    /// permission flow, and initial network stack init.
    ///
    /// `checkForUpdatesInBackground()` is silent when no update is available; when one is,
    /// it surfaces the standard Sparkle "Update Available" dialog — same path as the
    /// scheduled 24h check, just kicked off at a different time. No conflict with the
    /// scheduled check loop.
    func checkForUpdatesInBackgroundAfterLaunchSettle() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 15) { [weak self] in
            self?.controller.updater.checkForUpdatesInBackground()
        }
    }
}
