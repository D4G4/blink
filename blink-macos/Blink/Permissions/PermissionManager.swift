import Foundation
import AppKit
import CoreGraphics
import UserNotifications

/// Manages system permissions for sandboxed (App Store/TestFlight) builds.
enum PermissionManager {
    /// Check if we have permission to monitor input.
    /// Uses CGEventTap probe — works in sandbox where AXIsProcessTrusted always returns false.
    static func isPermissionGranted() -> Bool {
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
            return true
        }
        return false
    }

    /// Opens System Settings to the Accessibility pane.
    static func openAccessibilitySettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }

    /// Request notification permission.
    static func requestNotifications() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            return granted
        } catch {
            print("[Blink] Notification permission error: \(error)")
            return false
        }
    }
}
