import Foundation
import AppKit
import UserNotifications

/// Manages system permissions for Accessibility and Notifications.
enum PermissionManager {
    /// Check if Accessibility permission is currently granted.
    static func isAccessibilityGranted() -> Bool {
        AXIsProcessTrusted()
    }

    /// Request Accessibility permission (shows system prompt if not already granted).
    static func requestAccessibility() {
        guard !isAccessibilityGranted() else { return }
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
