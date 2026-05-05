import Foundation
import UserNotifications

/// Manages break reminder notifications with 3-tier escalation.
final class BreakNotificationManager {
    private var hasRequestedPermission = false

    func showBreakReminder() {
        Task {
            if !hasRequestedPermission {
                hasRequestedPermission = true
                _ = await PermissionManager.requestNotifications()
            }

            let content = UNMutableNotificationContent()
            content.title = "Time for a break"
            content.body = "Look at something 20 feet away for 20 seconds."
            content.sound = .default
            content.categoryIdentifier = "BREAK_REMINDER"

            let request = UNNotificationRequest(
                identifier: "blink-break-\(UUID().uuidString)",
                content: content,
                trigger: nil // immediate
            )

            do {
                try await UNUserNotificationCenter.current().add(request)
            } catch {
                print("[Blink] Failed to show notification: \(error)")
            }
        }
    }

    func dismiss() {
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
    }

    /// Register notification categories with action buttons.
    static func registerCategories() {
        let takeBreak = UNNotificationAction(
            identifier: "TAKE_BREAK",
            title: "Take Break",
            options: [.foreground]
        )
        let snooze = UNNotificationAction(
            identifier: "SNOOZE_5",
            title: "Snooze 5 min",
            options: []
        )
        let dismiss = UNNotificationAction(
            identifier: "DISMISS",
            title: "Dismiss",
            options: [.destructive]
        )

        let category = UNNotificationCategory(
            identifier: "BREAK_REMINDER",
            actions: [takeBreak, snooze, dismiss],
            intentIdentifiers: []
        )

        UNUserNotificationCenter.current().setNotificationCategories([category])
    }
}
