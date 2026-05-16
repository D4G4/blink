import Foundation
import AppKit
import CoreAudio
import BlinkCore
import os

/// Detects mic use, Focus mode, fullscreen apps, and video playback.
final class MacContextDetector: ContextSource {
    /// When true, mic detection is disabled (user has Dictation/Siri keeping mic open).
    private var micDetectionDisabled: Bool {
        // Key absent = nil = default to enabled. Only disabled when explicitly set to false.
        UserDefaults.standard.object(forKey: "pauseDuringCalls") != nil
            && !UserDefaults.standard.bool(forKey: "pauseDuringCalls")
    }

    private var isFirstMicCheck = true

    /// Called when mic is detected as active on first check (likely Dictation/Siri).
    /// Set by AppState to show a warning.
    var onMicActiveAtLaunch: (() -> Void)?

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

    private var lastMicState = false

    func isMicrophoneActive() -> Bool {
        guard !micDetectionDisabled else { return false }
        let active = isMicInUse()

        // First check: if mic is already active at launch, it's likely Dictation/Siri.
        // Warn the user once and auto-disable mic detection.
        if isFirstMicCheck {
            isFirstMicCheck = false
            if active {
                BlinkLog.context.info("Mic active at launch — likely Dictation/Siri, disabling mic detection")
                UserDefaults.standard.set(false, forKey: "pauseDuringCalls")
                onMicActiveAtLaunch?()
                lastMicState = false
                return false
            }
        }

        if active != lastMicState {
            BlinkLog.context.info("Mic state changed: \(active ? "ACTIVE" : "inactive")")
            if active { logAllDevices() }
            lastMicState = active
        }
        return active
    }

    /// Log all audio devices and their input/output stream counts for debugging.
    private func logAllDevices() {
        var size: UInt32 = 0
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size) == noErr else { return }
        let count = Int(size) / MemoryLayout<AudioDeviceID>.size
        var devices = [AudioDeviceID](repeating: 0, count: count)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &devices) == noErr else { return }

        for device in devices {
            var nameSize: UInt32 = 256
            var nameAddr = AudioObjectPropertyAddress(
                mSelector: kAudioObjectPropertyName, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain
            )
            var name: CFString = "" as CFString
            AudioObjectGetPropertyData(device, &nameAddr, 0, nil, &nameSize, &name)

            let inputOnly = isInputOnlyDevice(device)
            let hasInput = hasInputStreams(device)
            BlinkLog.context.info("Device \(device): \(name as String), hasInput=\(hasInput), inputOnly=\(inputOnly)")
        }
    }

    func isCameraActive() -> Bool {
        // Reliable camera detection in sandbox is limited.
        // Mic active already covers most call scenarios (Zoom, Teams, Meet).
        // For camera-only situations (e.g. recording), mic is usually also active.
        return false
    }

    /// Check if the microphone is actively recording on any audio device.
    ///
    /// `kAudioDevicePropertyDeviceIsRunningSomewhere` with global scope returns true when
    /// EITHER input or output is active — false positive when audio is just playing.
    /// We use a two-pronged approach:
    /// 1. Input-only devices (built-in mic): check `DeviceIsRunningSomewhere` — always reliable.
    /// 2. Combination devices (AirPods, USB headsets): check if any input stream is active
    ///    using `kAudioStreamPropertyIsActive` on input-scoped streams only.
    private func isMicInUse() -> Bool {
        var devicesSize: UInt32 = 0
        var devicesAddr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        guard AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject), &devicesAddr, 0, nil, &devicesSize
        ) == noErr, devicesSize > 0 else {
            return false
        }

        let deviceCount = Int(devicesSize) / MemoryLayout<AudioDeviceID>.size
        var devices = [AudioDeviceID](repeating: 0, count: deviceCount)
        guard AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &devicesAddr, 0, nil, &devicesSize, &devices
        ) == noErr else {
            return false
        }

        for device in devices {
            // Skip devices with no input capability
            guard hasInputStreams(device) else { continue }

            if isInputOnlyDevice(device) {
                // Input-only device (e.g. built-in mic): DeviceIsRunningSomewhere is reliable
                var isRunning: UInt32 = 0
                var size = UInt32(MemoryLayout<UInt32>.size)
                var addr = AudioObjectPropertyAddress(
                    mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
                    mScope: kAudioObjectPropertyScopeGlobal,
                    mElement: kAudioObjectPropertyElementMain
                )
                if AudioObjectGetPropertyData(device, &addr, 0, nil, &size, &isRunning) == noErr,
                   isRunning != 0 {
                    BlinkLog.context.debug("Mic in use: input-only device \(device) is running")
                    return true
                }
            } else {
                // Combination device (AirPods, USB headset): check input streams individually
                if hasActiveInputStream(device) {
                    BlinkLog.context.debug("Mic in use: combo device \(device) has active input stream")
                    return true
                }
            }
        }

        return false
    }

    private func hasInputStreams(_ deviceID: AudioDeviceID) -> Bool {
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreams,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )
        var size: UInt32 = 0
        AudioObjectGetPropertyDataSize(deviceID, &addr, 0, nil, &size)
        return size > 0
    }

    private func isInputOnlyDevice(_ deviceID: AudioDeviceID) -> Bool {
        var outputAddr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreams,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        var outputSize: UInt32 = 0
        AudioObjectGetPropertyDataSize(deviceID, &outputAddr, 0, nil, &outputSize)
        return outputSize == 0
    }

    private func hasActiveInputStream(_ deviceID: AudioDeviceID) -> Bool {
        var streamAddr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreams,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )
        var streamSize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(deviceID, &streamAddr, 0, nil, &streamSize) == noErr,
              streamSize > 0 else { return false }

        let count = Int(streamSize) / MemoryLayout<AudioStreamID>.size
        var streams = [AudioStreamID](repeating: 0, count: count)
        guard AudioObjectGetPropertyData(deviceID, &streamAddr, 0, nil, &streamSize, &streams) == noErr else {
            return false
        }

        for stream in streams {
            var isActive: UInt32 = 0
            var size = UInt32(MemoryLayout<UInt32>.size)
            var activeAddr = AudioObjectPropertyAddress(
                mSelector: kAudioStreamPropertyIsActive,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            if AudioObjectGetPropertyData(stream, &activeAddr, 0, nil, &size, &isActive) == noErr,
               isActive != 0 {
                return true
            }
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
