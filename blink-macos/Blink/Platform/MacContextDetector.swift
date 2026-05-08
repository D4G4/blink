import Foundation
import AppKit
import CoreAudio
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
        "com.cisco.webexmeetingsapp",
        "com.google.Chrome",          // Google Meet runs in browser
        "com.apple.Safari",
        "org.mozilla.firefox",
        "com.microsoft.edgemac",
        "com.brave.Browser",
        "company.thebrowser.Browser",  // Arc
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
        // Check if the system default input device (mic) is actually in use
        // by any app — works regardless of which app is frontmost
        guard isMicInUse() else { return false }

        // Mic is active — check if a meeting/browser app is running
        // (filters out false positives from music recording, voice memos, etc.)
        let runningApps = NSWorkspace.shared.runningApplications
        return runningApps.contains { app in
            guard let bundleID = app.bundleIdentifier else { return false }
            return Self.meetingApps.contains(bundleID) && !app.isHidden
        }
    }

    func isCameraActive() -> Bool {
        // Camera-in-use detection via CoreAudio isn't available,
        // but if the mic is in use with a meeting app, camera is likely on too.
        // Also check if a meeting app is frontmost as a secondary signal.
        if let frontApp = NSWorkspace.shared.frontmostApplication?.bundleIdentifier,
           Self.meetingApps.contains(frontApp) {
            return true
        }
        return false
    }

    /// Check if the default audio input device is running (mic in use by any app).
    private func isMicInUse() -> Bool {
        var defaultDevice = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        let err = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &defaultDevice
        )
        guard err == noErr, defaultDevice != 0 else { return false }

        var isRunning: UInt32 = 0
        size = UInt32(MemoryLayout<UInt32>.size)
        address.mSelector = kAudioDevicePropertyDeviceIsRunningSomewhere

        let err2 = AudioObjectGetPropertyData(defaultDevice, &address, 0, nil, &size, &isRunning)
        guard err2 == noErr else { return false }

        return isRunning != 0
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
