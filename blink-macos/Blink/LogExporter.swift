import AppKit

/// Exports logs from BlinkLog's in-memory buffer to the clipboard.
enum LogExporter {
    static func exportToFile() {
        let content = BlinkLog.export()
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(content, forType: .string)
    }
}
