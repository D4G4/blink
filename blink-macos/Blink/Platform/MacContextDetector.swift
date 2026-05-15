import Foundation
import AppKit
import CoreAudio
import BlinkCore
import os

private let log = Logger(subsystem: "com.blink20.app", category: "Context")

/// Detects meeting state, Focus mode, fullscreen apps, and video playback.
final class MacContextDetector: ContextSource {
    /// Dedicated meeting apps — running + mic in use = meeting
    private static let dedicatedMeetingApps: Set<String> = [
        "us.zoom.xos",
        "com.microsoft.teams",
        "com.microsoft.teams2",
        "com.apple.FaceTime",
        "com.webex.meetingmanager",
        "com.cisco.webexmeetingsapp",
    ]

    /// Meeting title keywords for browser-based meetings (Google Meet, etc.)
    private static let meetingTitleKeywords: [String] = [
        "meet.google.com", "google meet",
        "zoom.us",
        "teams.microsoft.com", "teams.live.com",
        "webex.com",
    ]

    /// Tracks whether a browser-based meeting was detected.
    /// Stays true while mic remains active, even if user switches apps.
    private var browserMeetingDetected = false

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
        let micInUse = isMicInUse()
        if !micInUse { browserMeetingDetected = false }
        return micInUse
    }

    func isCameraActive() -> Bool {
        // Reliable camera detection in sandbox is limited.
        // Mic active already covers most call scenarios (Zoom, Teams, Meet).
        // For camera-only situations (e.g. recording), mic is usually also active.
        return false
    }

    /// Returns true if a dedicated meeting app is running, or a browser-based
    /// meeting was detected. Browser meetings latch on (stay active) while the
    /// mic remains in use, so switching to iTerm mid-call doesn't exit meeting state.
    private func isMeetingAppActive() -> Bool {
        // Dedicated meeting app running (doesn't need to be frontmost)
        let runningApps = NSWorkspace.shared.runningApplications
        let hasDedicatedApp = runningApps.contains { app in
            guard let bundleID = app.bundleIdentifier else { return false }
            return Self.dedicatedMeetingApps.contains(bundleID) && !app.isHidden
        }
        if hasDedicatedApp { return true }

        // Browser frontmost with meeting title — latch on
        if let frontApp = NSWorkspace.shared.frontmostApplication,
           let bundleID = frontApp.bundleIdentifier,
           Self.browsers.contains(bundleID),
           let title = windowTitle(for: frontApp)?.lowercased() {
            if Self.meetingTitleKeywords.contains(where: { title.contains($0) }) {
                browserMeetingDetected = true
                return true
            }
        }

        // Mic still active after browser meeting was detected — stay in meeting
        if browserMeetingDetected {
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

        let axWindow = window as! AXUIElement
        guard CFGetTypeID(axWindow) == AXUIElementGetTypeID() else { return false }

        var fullscreenValue: AnyObject?
        guard AXUIElementCopyAttributeValue(
            axWindow,
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

        let axWindow = window as! AXUIElement
        guard CFGetTypeID(axWindow) == AXUIElementGetTypeID() else { return nil }

        var titleValue: AnyObject?
        guard AXUIElementCopyAttributeValue(axWindow, kAXTitleAttribute as CFString, &titleValue) == .success,
              let title = titleValue as? String else { return nil }

        return title
    }
}
