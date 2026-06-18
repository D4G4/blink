import Foundation
import AppKit
import Darwin

/// Diagnoses how the *previous* session ended so we can tell crashes from
/// clean quits when the system isn't writing DiagnosticReports.
///
/// Mechanism:
/// 1. On launch, read a UserDefaults flag set by the last session. If it
///    says "in progress," the last session didn't reach `willTerminate` —
///    that's either a crash (signal caught → marker file has the number),
///    a force-quit / OOM kill (SIGKILL, uncatchable, no marker), or a
///    sudden power loss.
/// 2. Install signal handlers for catchable fatal signals. They write a
///    single byte (signal number) to a pre-opened FD, then re-raise so
///    the OS still produces a crash dump if one would have been made.
/// 3. On `applicationWillTerminate` and `willPowerOff`, mark the flag
///    clean so the next launch knows.
enum LifecycleLogger {

    private static let lastSessionCleanKey = "blink.lastSessionEndedCleanly"

    private static let crashMarkerPath: String = {
        let base = NSSearchPathForDirectoriesInDomains(
            .applicationSupportDirectory, .userDomainMask, true
        ).first ?? NSTemporaryDirectory()
        let dir = (base as NSString).appendingPathComponent("Blink")
        try? FileManager.default.createDirectory(
            atPath: dir, withIntermediateDirectories: true
        )
        return (dir as NSString).appendingPathComponent("last-crash-signal")
    }()

    /// FD held open for the lifetime of the process so signal handlers can
    /// `write(2)` without doing anything async-signal-unsafe.
    fileprivate static var crashMarkerFD: Int32 = -1

    static func install() {
        reportPreviousSession()
        clearCrashMarker()
        openCrashMarkerFD()
        installSignalHandlers()
        markSessionInProgress()
        subscribeToSystemEvents()

        let pid = getpid()
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        BlinkLog.app.info("⏵ Session start | v\(version) (\(build)) | pid \(pid)")
    }

    // MARK: - Previous-session post-mortem

    private static func reportPreviousSession() {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: lastSessionCleanKey) != nil else {
            BlinkLog.app.info("First launch — no previous session to report")
            return
        }

        if defaults.bool(forKey: lastSessionCleanKey) {
            BlinkLog.app.info("Previous session ended cleanly")
            return
        }

        if let sig = readCrashMarker() {
            BlinkLog.app.error("⚠️ Previous session crashed on \(signalName(sig)) (\(sig))")
        } else {
            BlinkLog.app.error(
                "⚠️ Previous session ended without clean shutdown and no signal was caught. " +
                "Likely SIGKILL (Force Quit / OOM kill / `kill -9`), sudden power loss, or " +
                "kernel panic."
            )
        }
    }

    private static func readCrashMarker() -> Int32? {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: crashMarkerPath)),
              let first = data.first else { return nil }
        return Int32(first)
    }

    private static func clearCrashMarker() {
        try? FileManager.default.removeItem(atPath: crashMarkerPath)
    }

    private static func openCrashMarkerFD() {
        // O_TRUNC ensures any stale content is gone. Mode 0o644.
        crashMarkerFD = crashMarkerPath.withCString { path in
            open(path, O_WRONLY | O_CREAT | O_TRUNC, 0o644)
        }
        if crashMarkerFD < 0 {
            BlinkLog.app.error("Could not open crash marker FD (errno \(errno))")
        }
    }

    // MARK: - Session flag

    private static func markSessionInProgress() {
        UserDefaults.standard.set(false, forKey: lastSessionCleanKey)
        UserDefaults.standard.synchronize()
    }

    private static func markCleanExit(reason: String) {
        BlinkLog.app.info("⏹ Session end (clean): \(reason)")
        UserDefaults.standard.set(true, forKey: lastSessionCleanKey)
        UserDefaults.standard.synchronize()
    }

    // MARK: - Signal handlers

    private static func installSignalHandlers() {
        // Catchable fatal signals worth knowing about. SIGKILL and SIGSTOP
        // are uncatchable by design — those show up as "no marker, flag dirty."
        let signals: [Int32] = [
            SIGABRT, SIGBUS, SIGFPE, SIGILL, SIGSEGV, SIGSYS, SIGTRAP, SIGTERM, SIGPIPE,
        ]
        let handler: @convention(c) (Int32) -> Void = { signum in
            // Async-signal-safe: write one byte then re-raise. UserDefaults,
            // os_log, Swift String formatting — none of those are safe here.
            if LifecycleLogger.crashMarkerFD >= 0 {
                var byte = UInt8(truncatingIfNeeded: signum)
                _ = withUnsafePointer(to: &byte) { ptr in
                    write(LifecycleLogger.crashMarkerFD, ptr, 1)
                }
                _ = fsync(LifecycleLogger.crashMarkerFD)
            }
            // Restore default disposition and re-raise so the OS still
            // produces a crash report if it would have.
            signal(signum, SIG_DFL)
            raise(signum)
        }
        for sig in signals {
            signal(sig, handler)
        }
    }

    private static func signalName(_ sig: Int32) -> String {
        switch sig {
        case SIGABRT: return "SIGABRT"
        case SIGBUS:  return "SIGBUS"
        case SIGFPE:  return "SIGFPE"
        case SIGILL:  return "SIGILL"
        case SIGSEGV: return "SIGSEGV"
        case SIGSYS:  return "SIGSYS"
        case SIGTRAP: return "SIGTRAP"
        case SIGTERM: return "SIGTERM"
        case SIGPIPE: return "SIGPIPE"
        default:      return "signal-\(sig)"
        }
    }

    // MARK: - System events

    private static func subscribeToSystemEvents() {
        let nc = NotificationCenter.default
        nc.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil, queue: .main
        ) { _ in
            markCleanExit(reason: "applicationWillTerminate")
        }

        let ws = NSWorkspace.shared.notificationCenter
        ws.addObserver(
            forName: NSWorkspace.willPowerOffNotification,
            object: nil, queue: .main
        ) { _ in
            markCleanExit(reason: "system willPowerOff (logout/shutdown)")
        }
        ws.addObserver(
            forName: NSWorkspace.sessionDidResignActiveNotification,
            object: nil, queue: .main
        ) { _ in
            BlinkLog.app.info("User session resigned active (fast-user-switch or lock)")
        }
        ws.addObserver(
            forName: NSWorkspace.sessionDidBecomeActiveNotification,
            object: nil, queue: .main
        ) { _ in
            BlinkLog.app.info("User session became active")
        }
    }
}
