import Foundation
import EventKit

/// Watches the user's calendars and maps EventKit events into plain
/// `CalendarMeeting` values for the pure decision layer. Modeled on
/// `MacAppMonitor`: explicit start/stop, a single observer token, and NO timer
/// of its own — `AppState`'s 1 Hz tick drives periodic evaluation, while
/// `.EKEventStoreChanged` drives an immediate re-evaluation when the calendar
/// database is edited.
///
/// EventKit lives ONLY here; the decision logic (`CalendarPauseCoordinator`)
/// never sees an `EKEvent`.
final class MacCalendarMonitor {
    private let store = EKEventStore()
    private var observation: NSObjectProtocol?

    /// Fired (on the main queue) when the calendar database changes.
    var onStoreChanged: (() -> Void)?

    /// Full calendar read access (macOS 14+ `.fullAccess`). All queries are
    /// gated on this so we never touch the store without a live grant.
    var isAuthorized: Bool {
        EKEventStore.authorizationStatus(for: .event) == .fullAccess
    }

    func start() {
        guard observation == nil else { return }
        observation = NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged,
            object: store,
            queue: .main
        ) { [weak self] _ in
            self?.onStoreChanged?()
        }
    }

    func stop() {
        if let observation {
            NotificationCenter.default.removeObserver(observation)
        }
        observation = nil
    }

    deinit { stop() }

    /// Events overlapping `[now, now + ahead]`, mapped to `CalendarMeeting`.
    /// An ongoing meeting (started earlier, still running) overlaps `now` and
    /// is therefore included — so launching mid-meeting is handled. Returns []
    /// when unauthorized.
    func meetings(now: Date, ahead: TimeInterval = 60) -> [CalendarMeeting] {
        guard isAuthorized else { return [] }
        let predicate = store.predicateForEvents(
            withStart: now,
            end: now.addingTimeInterval(max(1, ahead)),
            calendars: nil
        )
        return store.events(matching: predicate).compactMap(Self.map)
    }

    private static func map(_ event: EKEvent) -> CalendarMeeting? {
        guard let id = event.eventIdentifier,
              let start = event.startDate,
              let end = event.endDate else { return nil }
        let link = MeetingLinkDetector.detect(
            urlString: event.url?.absoluteString,
            notes: event.notes,
            location: event.location
        )
        return CalendarMeeting(
            eventID: id,
            title: event.title ?? "Meeting",
            start: start,
            end: end,
            isAllDay: event.isAllDay,
            isDeclined: Self.isDeclined(event),
            link: link
        )
    }

    /// Whether the current user declined the invite. EventKit exposes the
    /// attendee list; find "self" and check the participant status.
    private static func isDeclined(_ event: EKEvent) -> Bool {
        guard let attendees = event.attendees else { return false }
        for attendee in attendees where attendee.isCurrentUser {
            return attendee.participantStatus == .declined
        }
        return false
    }
}
