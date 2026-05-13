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

    /// Request Input Monitoring permission (shows system prompt).
    static func requestInputMonitoring() {
        guard !isInputMonitoringGranted() else { return }
        CGRequestListenEventAccess()
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
