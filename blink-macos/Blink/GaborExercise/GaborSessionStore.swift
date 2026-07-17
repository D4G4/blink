import Foundation

struct GaborSessionRecord: Codable {
    let date: Date
    let exerciseType: String
    let trialCount: Int
    let correctCount: Int
    let contrastThreshold: Double?
    let durationSeconds: TimeInterval
    /// Session spatial frequency (cycles/deg). Optional so records written
    /// before multi-SF sessions still decode.
    var spatialFrequency: Double? = nil
}

/// Persists Gabor exercise session records as JSON in Application Support.
final class GaborSessionStore {
    static let shared = GaborSessionStore()

    private let directory: URL

    private init() {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.temporaryDirectory

        directory = appSupport
            .appendingPathComponent("Blink", isDirectory: true)
            .appendingPathComponent("GaborSessions", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    func save(_ record: GaborSessionRecord) {
        let formatter = Self.dateFormatter
        let dateString = formatter.string(from: record.date)
        let fileURL = directory.appendingPathComponent("\(dateString).json")

        var records = loadRecords(at: fileURL)
        records.append(record)

        do {
            let data = try JSONEncoder().encode(records)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("[Blink] Failed to save Gabor session: \(error)")
        }
    }

    func loadAll() -> [GaborSessionRecord] {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey]
        ) else { return [] }

        return files
            .filter { $0.pathExtension == "json" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
            .flatMap { loadRecords(at: $0) }
    }

    func loadRecent(days: Int = 30) -> [GaborSessionRecord] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        return loadAll().filter { $0.date >= cutoff }
    }

    func sessionsThisWeek() -> Int {
        let startOfWeek = Calendar.current.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
        return loadAll().filter { $0.date >= startOfWeek }.count
    }

    func bestThreshold(for exerciseType: String) -> Double? {
        loadAll()
            .filter { $0.exerciseType == exerciseType }
            .compactMap { $0.contrastThreshold }
            .min()
    }

    /// Most recent measured threshold for a given exercise at a given spatial
    /// frequency — used to carry difficulty forward between sessions.
    func lastThreshold(forExercise exerciseType: String, sf: Double) -> Double? {
        loadAll()
            .filter { $0.exerciseType == exerciseType && $0.spatialFrequency == sf }
            .sorted { $0.date < $1.date }
            .compactMap { $0.contrastThreshold }
            .last
    }

    /// Chronological threshold history for an exercise (across all SFs), for the
    /// progress trend. Returns (date, threshold) pairs, oldest first.
    func thresholdHistory(forExercise exerciseType: String, limit: Int = 20) -> [(date: Date, threshold: Double)] {
        let pairs = loadAll()
            .filter { $0.exerciseType == exerciseType }
            .sorted { $0.date < $1.date }
            .compactMap { rec -> (date: Date, threshold: Double)? in
                guard let t = rec.contrastThreshold else { return nil }
                return (rec.date, t)
            }
        return Array(pairs.suffix(limit))
    }

    // MARK: - Helpers

    private func loadRecords(at url: URL) -> [GaborSessionRecord] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        return (try? JSONDecoder().decode([GaborSessionRecord].self, from: data)) ?? []
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
}
