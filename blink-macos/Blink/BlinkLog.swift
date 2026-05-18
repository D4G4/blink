import os
import Foundation

/// Centralized logger. Logs to os.Logger (Console.app), an in-memory ring
/// buffer (clipboard export), and a daily log file on disk (survives quit).
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

    // MARK: - File logging

    private static let logsDir: URL? = {
        guard let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first else { return nil }
        let dir = appSupport
            .appendingPathComponent("Blink", isDirectory: true)
            .appendingPathComponent("Logs", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    private static var fileHandle: FileHandle?

    /// Creates a new session log file: Logs/2026-05-18/session-13-34-14.log
    private static func currentFileHandle() -> FileHandle? {
        if let handle = fileHandle { return handle }

        guard let dir = logsDir else { return nil }

        // Day folder
        let dayDir = dir.appendingPathComponent(dayFormatter.string(from: sessionStart), isDirectory: true)
        try? FileManager.default.createDirectory(at: dayDir, withIntermediateDirectories: true)

        // Session file named by start time
        let fileURL = dayDir.appendingPathComponent("session-\(timeFormatter.string(from: sessionStart)).log")
        FileManager.default.createFile(atPath: fileURL.path, contents: nil)
        guard let handle = try? FileHandle(forWritingTo: fileURL) else { return nil }

        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        let header = "Blink v\(version) (\(build)) | macOS \(ProcessInfo.processInfo.operatingSystemVersionString) | \(ISO8601DateFormatter().string(from: sessionStart))\n\n"
        handle.write(Data(header.utf8))

        fileHandle = handle
        return handle
    }

    private static let sessionStart = Date()

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH-mm-ss"
        return f
    }()

    // MARK: - Core

    static func append(_ entry: String) {
        lock.lock()
        defer { lock.unlock() }

        entries.append(entry)
        if entries.count > maxEntries {
            entries.removeFirst(entries.count - maxEntries)
        }

        // Write to disk
        if let handle = currentFileHandle() {
            handle.write(Data((entry + "\n").utf8))
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

    /// Remove day folders older than `days` days.
    static func pruneOldLogs(olderThan days: Int = 7) {
        guard let dir = logsDir else { return }
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()

        guard let items = try? FileManager.default.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: [.isDirectoryKey]
        ) else { return }

        for item in items {
            let isDir = (try? item.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            guard isDir else { continue }
            // Folder name: 2026-05-18
            if let folderDate = dayFormatter.date(from: item.lastPathComponent), folderDate < cutoff {
                try? FileManager.default.removeItem(at: item)
            }
        }
    }

    /// URL of the Logs directory, for opening in Finder.
    static var logDirectoryURL: URL? { logsDir }
}

/// Thin wrapper: logs to os.Logger + in-memory buffer + disk.
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
