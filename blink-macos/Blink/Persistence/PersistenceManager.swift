import Foundation
import BlinkCore

/// Manages break history persistence as daily JSON files.
final class PersistenceManager {
    private let baseURL: URL

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        baseURL = appSupport.appendingPathComponent("Blink", isDirectory: true)

        // Create directory if needed
        try? FileManager.default.createDirectory(at: baseURL, withIntermediateDirectories: true)
    }

    // MARK: - Break Records

    func saveBreakRecord(_ record: BreakRecord) {
        var records = loadTodayRecords()
        records.append(record)

        let fileURL = urlForDate(Date())
        do {
            let data = try JSONEncoder().encode(records)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("[Blink] Failed to save break record: \(error)")
        }
    }

    func loadTodayRecords() -> [BreakRecord] {
        loadRecords(for: Date())
    }

    func loadRecords(for date: Date) -> [BreakRecord] {
        let fileURL = urlForDate(date)
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        return (try? JSONDecoder().decode([BreakRecord].self, from: data)) ?? []
    }

    /// Remove break history files older than `days` days.
    func pruneOldRecords(olderThan days: Int = 30) {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let formatter = Self.dateFormatter

        guard let files = try? FileManager.default.contentsOfDirectory(at: baseURL, includingPropertiesForKeys: nil) else { return }

        for file in files where file.pathExtension == "json" {
            let name = file.deletingPathExtension().lastPathComponent
            if let fileDate = formatter.date(from: name), fileDate < cutoff {
                try? FileManager.default.removeItem(at: file)
            }
        }
    }

    // MARK: - Helpers

    private func urlForDate(_ date: Date) -> URL {
        let name = Self.dateFormatter.string(from: date)
        return baseURL.appendingPathComponent("\(name).json")
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
}
