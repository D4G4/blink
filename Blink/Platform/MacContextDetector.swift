import Foundation
import AppKit
import BlinkCore
import os

private let log = Logger(subsystem: "com.blink.app", category: "Context")

/// Detects meeting state, Focus mode, fullscreen apps, and video playback.
final class MacContextDetector: ContextSource {
    private static let meetingApps: Set<String> = [
        "us.zoom.xos",
        "com.microsoft.teams",
        "com.microsoft.teams2",
        "com.apple.FaceTime",
        "com.webex.meetingmanager",
    ]

    /// Apps where being frontmost = watching video
    private static let videoApps: Set<String> = [
        "com.apple.TV",
        "com.apple.QuickTimePlayerX",
        "org.videolan.vlc",
        "io.mpv",
        "com.colliderli.iina",
        "com.netflix.Netflix",
        "com.disney.disneyplus",
        "com.amazon.aiv.AIVApp",
        "com.plex.plex-player",
        "tv.plex.player",
        "com.plexapp.plex",
    ]

    /// Browsers — check window title for video sites
    private static let browsers: Set<String> = [
        "com.apple.Safari",
        "com.google.Chrome",
        "org.mozilla.firefox",
        "com.microsoft.edgemac",
        "com.brave.Browser",
        "company.thebrowser.Browser",  // Arc
    ]

    /// Window title keywords that indicate video content
    private static let videoTitleKeywords: [String] = [
        "youtube", "netflix", "hulu", "disney+", "prime video",
        "twitch", "vimeo", "dailymotion", "hbo", "peacock",
        "crunchyroll", "plex", "apple tv",
    ]

    func isMicrophoneActive() -> Bool {
        let runningApps = NSWorkspace.shared.runningApplications
        let meetingAppRunning = runningApps.contains { app in
            guard let bundleID = app.bundleIdentifier else { return false }
            return Self.meetingApps.contains(bundleID) && !app.isHidden
        }
        return meetingAppRunning && isCameraActive()
    }

    func isCameraActive() -> Bool {
        if let frontApp = NSWorkspace.shared.frontmostApplication?.bundleIdentifier,
           Self.meetingApps.contains(frontApp) {
            return true
        }
        return false
    }

    func isInFocusMode() -> Bool {
        let defaults = UserDefaults(suiteName: "com.apple.controlcenter")
        return defaults?.bool(forKey: "NSStatusItem Visible FocusModes") ?? false
    }

    func isFrontAppFullScreen() -> Bool {
        guard let frontApp = NSWorkspace.shared.frontmostApplication else { return false }
        let pid = frontApp.processIdentifier
        let appRef = AXUIElementCreateApplication(pid)

        var windowValue: AnyObject?
        guard AXUIElementCopyAttributeValue(appRef, kAXFocusedWindowAttribute as CFString, &windowValue) == .success,
              let window = windowValue else { return false }

        var fullscreenValue: AnyObject?
        guard AXUIElementCopyAttributeValue(
            window as! AXUIElement,
            "AXFullScreen" as CFString,
            &fullscreenValue
        ) == .success else { return false }

        return (fullscreenValue as? Bool) ?? false
    }

    func isMediaPlaying() -> Bool {
        guard let frontApp = NSWorkspace.shared.frontmostApplication,
              let bundleID = frontApp.bundleIdentifier else { return false }

        // Video app is frontmost — user is watching
        if Self.videoApps.contains(bundleID) {
            return true
        }

        // Browser is frontmost — check window title for video sites
        if Self.browsers.contains(bundleID) {
            if let title = windowTitle(for: frontApp)?.lowercased() {
                return Self.videoTitleKeywords.contains { title.contains($0) }
            }
        }

        return false
    }

    private func windowTitle(for app: NSRunningApplication) -> String? {
        let appRef = AXUIElementCreateApplication(app.processIdentifier)
        var windowValue: AnyObject?
        guard AXUIElementCopyAttributeValue(appRef, kAXFocusedWindowAttribute as CFString, &windowValue) == .success,
              let window = windowValue else { return nil }

        var titleValue: AnyObject?
        guard AXUIElementCopyAttributeValue(window as! AXUIElement, kAXTitleAttribute as CFString, &titleValue) == .success,
              let title = titleValue as? String else { return nil }

        return title
    }
}
