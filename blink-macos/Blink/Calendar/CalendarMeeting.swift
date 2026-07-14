import Foundation

/// A calendar event reduced to the plain values Blink's pause logic needs,
/// decoupled from EventKit's `EKEvent` so the decision code stays pure and
/// unit-testable (and EventKit stays out of the decision layer entirely).
struct CalendarMeeting: Equatable {
    /// `EKEvent.eventIdentifier` — SHARED across every occurrence of a
    /// recurring series, so it alone is NOT a per-occurrence identity.
    let eventID: String
    let title: String
    let start: Date
    let end: Date
    let isAllDay: Bool
    /// The current user declined this invite (skip — they're not attending).
    let isDeclined: Bool
    let link: DetectedMeetingLink?

    /// Stable per-occurrence identity: series id + this occurrence's start.
    /// A daily standup shares `eventID` across days, so the start timestamp is
    /// what makes each day a distinct, separately-actionable occurrence.
    var occurrenceKey: String {
        "\(eventID)|\(Int(start.timeIntervalSinceReferenceDate))"
    }

    var hasLink: Bool { link != nil }

    /// True when `now` falls within `[start, end)` — i.e. the meeting is
    /// happening right now (also true for an event already underway at launch).
    func isActive(at now: Date) -> Bool {
        now >= start && now < end
    }
}
