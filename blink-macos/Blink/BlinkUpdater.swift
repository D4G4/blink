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
///
/// Beta channel: Sparkle 2 ships a `<sparkle:channel>` item attribute that
/// gates which appcast items reach which users. By default an updater
/// only consumes items with NO channel tag (= stable). When the user
/// opts into the beta channel via Settings, `allowedChannels(for:)` below
/// returns `["beta"]` — beta items become visible, AND stable items
/// remain visible (channel filtering is additive). Stable users never
/// see beta items.
@MainActor
final class BlinkUpdater: NSObject {
    static let shared = BlinkUpdater()

    private var controller: SPUStandardUpdaterController!

    /// UserDefaults key for the "Receive beta updates" toggle in Settings.
    /// Read via `UserDefaults.standard` rather than `@AppStorage` because
    /// this object is not a View — but the toggle UI binds to the same
    /// key so changes propagate.
    static let betaChannelKey = "betaChannelEnabled"

    private override init() {
        super.init()
        controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: self,
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

// MARK: - SPUUpdaterDelegate

extension BlinkUpdater: SPUUpdaterDelegate {
    /// Returns the additional channels this install accepts items from.
    /// Default install: empty → stable-only. Beta-opted-in install:
    /// `["beta"]` → stable + beta. Read fresh from UserDefaults every
    /// call so a toggle change takes effect on the very next check.
    nonisolated func allowedChannels(for updater: SPUUpdater) -> Set<String> {
        let enabled = UserDefaults.standard.bool(forKey: Self.betaChannelKey)
        return enabled ? ["beta"] : []
    }
}
