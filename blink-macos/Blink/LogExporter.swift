import AppKit

/// Exports logs from BlinkLog's in-memory buffer to the clipboard,
/// or reveals the on-disk log files in Finder.
enum LogExporter {
    static func exportToClipboard() {
        let content = BlinkLog.export()
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(content, forType: .string)
    }

    static func revealInFinder() {
        guard let url = BlinkLog.logDirectoryURL else { return }
        NSWorkspace.shared.open(url)
    }
}
