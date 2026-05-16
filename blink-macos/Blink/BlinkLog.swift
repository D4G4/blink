import os
import Foundation

/// Centralized logger. Logs to both os.Logger (for Console.app) and an in-memory
/// ring buffer (for clipboard export — no privacy redaction).
enum BlinkLog {
    static let app      = BlinkLogger("AppState")
    static let context  = BlinkLogger("Context")
    static let ui       = BlinkLogger("UI")
    static let menuBar  = BlinkLogger("MenuBar")
    static let update   = BlinkLogger("Update")
    static let permission = BlinkLogger("Permission")

    /// In-memory log entries for export. Thread-safe.
    private(set) static var entries: [String] = []
    private static let lock = NSLock()
    private static let maxEntries = 2000

    static func append(_ entry: String) {
        lock.lock()
        defer { lock.unlock() }
        entries.append(entry)
        if entries.count > maxEntries {
            entries.removeFirst(entries.count - maxEntries)
        }
    }

    static func export() -> String {
        lock.lock()
        defer { lock.unlock() }

        let header = """
        Blink Log Export
        ================
        Exported: \(ISO8601DateFormatter().string(from: Date()))
        Entries: \(entries.count)
        Version: \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?") (\(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"))
        macOS: \(ProcessInfo.processInfo.operatingSystemVersionString)

        """
        return header + entries.joined(separator: "\n")
    }
}

/// Thin wrapper: logs to os.Logger + in-memory buffer.
struct BlinkLogger {
    private let logger: Logger
    private let category: String

    init(_ category: String) {
        self.logger = Logger(subsystem: "com.blink20.app", category: category)
        self.category = category
    }

    func info(_ message: String) {
        logger.info("\(message, privacy: .public)")
        let ts = Self.timestamp()
        BlinkLog.append("[\(ts)] [INFO] [\(category)] \(message)")
    }

    func debug(_ message: String) {
        logger.debug("\(message, privacy: .public)")
        let ts = Self.timestamp()
        BlinkLog.append("[\(ts)] [DEBUG] [\(category)] \(message)")
    }

    func error(_ message: String) {
        logger.error("\(message, privacy: .public)")
        let ts = Self.timestamp()
        BlinkLog.append("[\(ts)] [ERROR] [\(category)] \(message)")
    }

    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()

    private static func timestamp() -> String {
        formatter.string(from: Date())
    }
}
