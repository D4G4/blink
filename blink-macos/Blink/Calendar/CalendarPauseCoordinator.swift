import Foundation

/// What the calendar layer wants Blink to do this evaluation.
enum CalendarPauseAction: Equatable {
    /// Do nothing.
    case none
    /// Auto-pause for this meeting (it has a video link).
    case autoPause(CalendarMeeting)
    /// Offer a dismissible "pause?" suggestion for this meeting (no link).
    case suggest(CalendarMeeting)
}

/// Pure decision for the calendar-driven pause. Given the current window of
/// meetings and the app's state, decide whether to auto-pause, suggest, or do
/// nothing. No side effects, no EventKit — `AppState` applies the result.
enum CalendarPauseCoordinator {
    /// - Parameters:
    ///   - meetings: events overlapping the current window (from the monitor).
    ///   - now: evaluation time.
    ///   - currentlyPaused: whether Blink is ALREADY paused (any mode). The
    ///     calendar layer never overrides an existing pause — this is what
    ///     preserves a user's manual "until tomorrow" pause when a meeting starts.
    ///   - actedKeys: occurrence keys already handled this run (paused or
    ///     suggested), so a meeting isn't re-acted every tick or re-nagged
    ///     after the user hits Undo.
    ///   - suggestUnlinked: whether link-less events get a suggestion toast.
    static func decide(
        meetings: [CalendarMeeting],
        now: Date,
        currentlyPaused: Bool,
        actedKeys: Set<String>,
        suggestUnlinked: Bool
    ) -> CalendarPauseAction {
        // Never stomp an existing pause (manual or an earlier calendar pause).
        guard !currentlyPaused else { return .none }

        // Actionable = happening now, real timed event, attending, not yet acted.
        let candidates = meetings.filter { m in
            m.isActive(at: now)
                && !m.isAllDay
                && !m.isDeclined
                && !actedKeys.contains(m.occurrenceKey)
        }
        guard !candidates.isEmpty else { return .none }

        // Prefer linked meetings (auto-pause is the primary behavior); among
        // ties, earliest start wins so the choice is deterministic.
        let linked = candidates.filter { $0.hasLink }.sorted { $0.start < $1.start }
        if let meeting = linked.first {
            return .autoPause(meeting)
        }

        guard suggestUnlinked else { return .none }
        if let meeting = candidates.sorted(by: { $0.start < $1.start }).first {
            return .suggest(meeting)
        }
        return .none
    }
}
