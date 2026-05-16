import Foundation
import AppKit
import CoreGraphics
import UserNotifications

/// Manages system permissions for sandboxed (App Store/TestFlight) builds.
enum PermissionManager {
    private static let log = BlinkLog.permission

    /// Check if we have permission to monitor input.
    /// Tries CGEventTap probe first (proves we can actually create a tap),
    /// then falls back to AXIsProcessTrusted (reflects TCC grant immediately,
    /// even in sandbox on macOS 15+, without needing a relaunch).
    static func isPermissionGranted() -> Bool {
        let pid = ProcessInfo.processInfo.processIdentifier
        let path = Bundle.main.bundlePath
        log.info("Checking permission (pid=\(pid), path=\(path))")

        let eventMask: CGEventMask = (1 << CGEventType.keyDown.rawValue)
        if let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .tailAppendEventTap,
            options: .listenOnly,
            eventsOfInterest: eventMask,
            callback: { _, _, event, _ in Unmanaged.passUnretained(event) },
            userInfo: nil
        ) {
            CGEvent.tapEnable(tap: tap, enable: false)
            log.info("CGEventTap probe succeeded — GRANTED")
            return true
        }

        log.info("CGEventTap probe failed (cached denial likely)")

        // CGEventTap can fail even after permission is granted because the running
        // process has a cached denial from before the TCC grant. AXIsProcessTrusted
        // reflects the updated grant immediately without requiring a relaunch.
        let axTrusted = AXIsProcessTrusted()
        if axTrusted {
            log.info("AXIsProcessTrusted fallback — GRANTED")
        } else {
            log.info("AXIsProcessTrusted fallback — DENIED")
        }
        return axTrusted
    }

    /// Opens System Settings to the Accessibility pane.
    static func openAccessibilitySettings() {
        log.info("Opening Accessibility settings pane")
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else { return }
        NSWorkspace.shared.open(url)
    }

    /// Request notification permission.
    static func requestNotifications() async -> Bool {
        log.info("Requesting notification permission")
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            log.info("Notification permission result: \(granted ? "granted" : "denied")")
            return granted
        } catch {
            log.error("Notification permission error: \(error)")
            return false
        }
    }
}
