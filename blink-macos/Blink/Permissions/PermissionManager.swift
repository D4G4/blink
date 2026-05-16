import Foundation
import AppKit
import CoreGraphics
import UserNotifications

/// Manages system permissions for sandboxed (App Store/TestFlight) builds.
enum PermissionManager {
    private static let log = BlinkLog.permission

    /// Check if we have permission to monitor input.
    /// Checks AXIsProcessTrusted first (lightweight, no system prompts),
    /// then tries CGEventTap probe only if AX reports trusted (to verify
    /// we can actually create a tap). This avoids triggering the
    /// "Keystroke Receiving" system dialog on macOS 26 when permission
    /// hasn't been granted yet.
    static func isPermissionGranted() -> Bool {
        let pid = ProcessInfo.processInfo.processIdentifier
        let path = Bundle.main.bundlePath
        log.info("Checking permission (pid=\(pid), path=\(path))")

        // Check AXIsProcessTrusted first — it's a lightweight TCC query
        // that never triggers system prompts.
        let axTrusted = AXIsProcessTrusted()
        log.info("AXIsProcessTrusted = \(axTrusted)")

        if !axTrusted {
            // Don't attempt CGEvent.tapCreate() — on macOS 26 it triggers
            // a "Keystroke Receiving" system dialog when not yet authorized.
            log.info("Permission DENIED (skipping CGEventTap probe to avoid system prompt)")
            return false
        }

        // AX says trusted — verify we can actually create an event tap.
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

        // AXIsProcessTrusted is true but CGEventTap failed — cached denial.
        // Trust AX; the real tap in MacInputMonitor will likely succeed
        // since it's created after TCC propagation.
        log.info("CGEventTap probe failed (cached denial) but AXIsProcessTrusted=true — GRANTED")
        return true
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
