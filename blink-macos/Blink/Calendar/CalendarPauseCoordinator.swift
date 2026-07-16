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
    ///   - leadTime: how far before an event starts to act, so the user is
    ///     covered before the meeting begins. Applies to BOTH paths — linked
    ///     events auto-pause and link-less events suggest `leadTime` early,
    ///     through the event's end.
    static func decide(
        meetings: [CalendarMeeting],
        now: Date,
        currentlyPaused: Bool,
        actedKeys: Set<String>,
        suggestUnlinked: Bool,
        leadTime: TimeInterval = 120
    ) -> CalendarPauseAction {
        // Never stomp an existing pause (manual or an earlier calendar pause).
        guard !currentlyPaused else { return .none }

        // Actionable = within the lead window (up to `leadTime` before start,
        // through end), real timed event, attending, not yet acted this run.
        func actionable(_ m: CalendarMeeting) -> Bool {
            m.isSuggestible(at: now, lead: leadTime)
                && !m.isAllDay && !m.isDeclined && !actedKeys.contains(m.occurrenceKey)
        }

        // Auto-pause (primary behavior) — a linked meeting. Among ties, earliest
        // start wins so the choice is deterministic.
        let linked = meetings
            .filter { $0.hasLink && actionable($0) }
            .sorted { $0.start < $1.start }
        if let meeting = linked.first {
            return .autoPause(meeting)
        }

        guard suggestUnlinked else { return .none }

        // Suggest — a link-less meeting.
        let suggestible = meetings
            .filter { !$0.hasLink && actionable($0) }
            .sorted { $0.start < $1.start }
        if let meeting = suggestible.first {
            return .suggest(meeting)
        }
        return .none
    }
}
