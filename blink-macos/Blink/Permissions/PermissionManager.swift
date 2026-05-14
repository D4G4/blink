import Foundation
import AppKit
import CoreGraphics
import UserNotifications

/// Manages system permissions for Accessibility and Notifications.
enum PermissionManager {
    /// Check if we can monitor input — works for both sandboxed and unsandboxed.
    /// Tries AXIsProcessTrusted first (unsandboxed), falls back to CGEventTap probe (sandboxed).
    static func isAccessibilityGranted() -> Bool {
        // AXIsProcessTrusted works for unsandboxed builds
        if AXIsProcessTrusted() { return true }

        // For sandboxed builds, AXIsProcessTrusted always returns false.
        // Try creating a CGEventTap — if it succeeds, we have permission.
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

    /// Request Accessibility permission (shows system prompt if not already granted).
    static func requestAccessibility() {
        guard !AXIsProcessTrusted() else { return }
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    /// Opens System Settings to the Accessibility pane directly.
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
