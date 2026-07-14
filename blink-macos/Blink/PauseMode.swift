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

    /// For a `.timed` pause, whether its deadline has passed. Always false for
    /// `.indefinite` and `.currentApp` (those resume conditions are stateful —
    /// user action / a grace timer — and live in `AppState.checkAutoResume`).
    func isElapsed(at now: Date) -> Bool {
        if case .timed(let until) = self { return now >= until }
        return false
    }

    /// Pure grace-timer step for a `.currentApp` pause. Given the current
    /// frontmost app (Blink's own id already filtered to `nil` by the caller)
    /// and the moment the user first left the paused app, returns the updated
    /// "away since" timestamp and whether the pause should now resume.
    ///
    /// - Back in the paused app → cancel the grace timer (`awaySince = nil`).
    /// - Frontmost unknown / Blink's own popover (`nil`) → hold, unchanged.
    /// - In a different app → start/continue the timer; resume once the
    ///   continuous absence reaches `graceSeconds`.
    static func currentAppGraceStep(
        pausedBundleID: String,
        frontmostBundleID: String?,
        awaySince: Date?,
        now: Date,
        graceSeconds: TimeInterval
    ) -> (awaySince: Date?, resume: Bool) {
        if frontmostBundleID == pausedBundleID {
            return (nil, false)
        }
        guard frontmostBundleID != nil else {
            return (awaySince, false)
        }
        let since = awaySince ?? now
        if now.timeIntervalSince(since) >= graceSeconds {
            return (nil, true)
        }
        return (since, false)
    }

    var logDescription: String {
        switch self {
        case .indefinite: return "indefinite"
        case .timed(let until): return "until \(until)"
        case .currentApp(_, let name): return "while \(name) is frontmost"
        }
    }
}
