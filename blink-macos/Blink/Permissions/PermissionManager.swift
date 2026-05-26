import Foundation
import AppKit
import CoreGraphics
import UserNotifications

/// Manages system permissions for sandboxed (App Store/TestFlight) builds.
enum PermissionManager {
    private static let log = BlinkLog.permission

    /// Check if we have permission to monitor input.
    /// Checks `CGPreflightListenEventAccess()` first (lightweight, no system prompts),
    /// then tries a CGEventTap probe only if preflight reports granted (to verify
    /// we can actually create a tap — TCC's grant cache can lag the API by a
    /// moment after a fresh grant).
    static func isPermissionGranted() -> Bool {
        let pid = ProcessInfo.processInfo.processIdentifier
        let path = Bundle.main.bundlePath
        log.info("Checking permission (pid=\(pid), path=\(path))")

        // Lightweight TCC query — never triggers system prompts.
        let preflight = CGPreflightListenEventAccess()
        log.info("CGPreflightListenEventAccess = \(preflight)")

        if !preflight {
            log.info("Permission DENIED (skipping CGEventTap probe to avoid system prompt)")
            return false
        }

        // Preflight says granted — verify we can actually create an event tap.
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

        // Preflight true but tap creation failed — cached denial.
        // Trust preflight; the real tap in MacInputMonitor will likely succeed
        // since it's created after TCC propagation.
        log.info("CGEventTap probe failed (cached denial) but preflight=true — GRANTED")
        return true
    }

    /// Trigger the system Input Monitoring grant prompt.
    /// Returns true if access is already granted, false if the user must respond
    /// to the system dialog (which appears asynchronously).
    @discardableResult
    static func requestInputMonitoringAccess() -> Bool {
        log.info("Requesting Input Monitoring access (system prompt)")
        return CGRequestListenEventAccess()
    }

    /// Opens System Settings to the Input Monitoring pane.
    static func openInputMonitoringSettings() {
        log.info("Opening Input Monitoring settings pane")
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") else { return }
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
