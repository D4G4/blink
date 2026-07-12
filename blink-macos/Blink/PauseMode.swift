import Foundation

/// How a manual pause of Blink ends.
///
/// `AppState.pauseMode == nil` means Blink is running normally. A non-nil
/// value freezes the break timer (the 1 Hz tick in `AppState.startTimer()`
/// skips `engine.tick()` while `isPaused`) until the mode's resume condition
/// is met — evaluated every tick by `AppState.checkAutoResume()`.
///
/// Pure value type with no platform imports so the resume decision and the
/// duration math stay trivially testable.
enum PauseMode: Equatable, Codable {
    /// Paused until the user manually resumes — the classic header-toggle pause.
    case indefinite
    /// Paused until `date` (wall clock). Backs the 1h / 6h / until-tomorrow options.
    case timed(until: Date)
    /// Paused while `bundleID` is the frontmost app; resumes the moment the
    /// user switches to any other app. `name` is the display name captured
    /// when the pause began.
    case currentApp(bundleID: String, name: String)

    // MARK: - Factories

    /// Pause for a fixed number of seconds from `now`.
    static func forDuration(_ seconds: TimeInterval, from now: Date = Date()) -> PauseMode {
        .timed(until: now.addingTimeInterval(seconds))
    }

    /// "Until tomorrow" — the next local midnight, from any time of day.
    static func untilTomorrow(from now: Date = Date(), calendar: Calendar = .current) -> PauseMode {
        let nextMidnight = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))
            ?? now.addingTimeInterval(24 * 3600)
        return .timed(until: nextMidnight)
    }

    // MARK: - Resume decision

    /// Whether the pause should end now.
    /// - Parameters:
    ///   - now: current wall-clock time.
    ///   - frontmostBundleID: the frontmost app's bundle id, with Blink's own
    ///     id already filtered to `nil` by the caller — so opening Blink's own
    ///     menu never trips a `.currentApp` resume.
    func shouldResume(now: Date, frontmostBundleID: String?) -> Bool {
        switch self {
        case .indefinite:
            return false
        case .timed(let until):
            return now >= until
        case .currentApp(let bundleID, _):
            // Unknown frontmost (nil) → stay paused; only a real switch to a
            // different app ends the pause.
            guard let front = frontmostBundleID else { return false }
            return front != bundleID
        }
    }

    var logDescription: String {
        switch self {
        case .indefinite: return "indefinite"
        case .timed(let until): return "until \(until)"
        case .currentApp(_, let name): return "while \(name) is frontmost"
        }
    }
}
