import Foundation
import AppKit
import UserNotifications
import CoreGraphics

/// Manages system permissions for Input Monitoring and Notifications.
enum PermissionManager {
    /// Check if Input Monitoring permission is currently granted.
    static func isInputMonitoringGranted() -> Bool {
        CGPreflightListenEventAccess()
    }

    /// Request Input Monitoring permission.
    /// First calls CGRequestListenEventAccess() for the system prompt,
    /// then attempts to create a CGEventTap which also triggers the prompt
    /// on some macOS versions where CGRequestListenEventAccess alone doesn't.
    static func requestInputMonitoring() {
        if !isInputMonitoringGranted() {
            // This should show the system prompt
            CGRequestListenEventAccess()

            // On some macOS versions, creating the tap itself triggers the prompt
            let eventMask: CGEventMask = (1 << CGEventType.keyDown.rawValue)
            if let tap = CGEvent.tapCreate(
                tap: .cgSessionEventTap,
                place: .tailAppendEventTap,
                options: .listenOnly,
                eventsOfInterest: eventMask,
                callback: { _, _, event, _ in Unmanaged.passUnretained(event) },
                userInfo: nil
            ) {
                // Tap created = permission was already granted, clean up
                CGEvent.tapEnable(tap: tap, enable: false)
            }
            // If tap creation fails, the system should have shown the prompt
        }
    }

    /// Opens System Settings to the Input Monitoring pane directly.
    static func openInputMonitoringSettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")!)
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
