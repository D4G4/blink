import Foundation
import AppKit
import OSLog
import UniformTypeIdentifiers

/// Exports recent Blink logs from the unified logging system.
enum LogExporter {
    /// Fetches all Blink logs from the last N hours and returns as a string.
    static func exportLogs(lastHours: Int = 4) -> String {
        do {
            let store = try OSLogStore(scope: .currentProcessIdentifier)
            let cutoff = store.position(date: Date().addingTimeInterval(-Double(lastHours * 3600)))
            let entries = try store.getEntries(at: cutoff)

            var lines: [String] = []
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "HH:mm:ss.SSS"

            for entry in entries {
                guard let logEntry = entry as? OSLogEntryLog,
                      logEntry.subsystem == "com.blink20.app" else { continue }
                let time = dateFormatter.string(from: logEntry.date)
                let level = levelString(logEntry.level)
                lines.append("[\(time)] [\(level)] [\(logEntry.category)] \(logEntry.composedMessage)")
            }

            if lines.isEmpty {
                return "No Blink logs found in the last \(lastHours) hours.\n\nThis can happen if the app was just launched. Try again after using the app for a few minutes."
            }

            let header = """
            Blink Log Export
            ================
            Exported: \(ISO8601DateFormatter().string(from: Date()))
            Period: last \(lastHours) hours (\(lines.count) entries)
            Version: \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?") (\(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"))
            macOS: \(ProcessInfo.processInfo.operatingSystemVersionString)

            """

            return header + lines.joined(separator: "\n")
        } catch {
            return "Failed to read logs: \(error.localizedDescription)"
        }
    }

    /// Exports logs to a temp file and opens a save panel.
    static func exportToFile() {
        let content = exportLogs()

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = "blink-logs-\(dateStamp()).txt"
        panel.title = "Export Blink Logs"

        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            do {
                try content.write(to: url, atomically: true, encoding: .utf8)
            } catch {
                print("[Blink] Failed to write log file: \(error)")
            }
        }
    }

    private static func dateStamp() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd-HHmm"
        return f.string(from: Date())
    }

    private static func levelString(_ level: OSLogEntryLog.Level) -> String {
        switch level {
        case .debug: return "DEBUG"
        case .info: return "INFO"
        case .notice: return "NOTICE"
        case .error: return "ERROR"
        case .fault: return "FAULT"
        default: return "?"
        }
    }
}
