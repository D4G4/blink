import XCTest
@testable import Blink

/// Pure-logic tests for the calendar pause decision.
final class CalendarPauseCoordinatorTests: XCTestCase {

    private let now = Date(timeIntervalSinceReferenceDate: 1_000_000)

    /// Build an active-now meeting (start 5 min ago, end 25 min out) unless
    /// overridden.
    private func meeting(
        id: String = "evt",
        title: String = "Sync",
        startOffset: TimeInterval = -300,
        endOffset: TimeInterval = 1500,
        isAllDay: Bool = false,
        isDeclined: Bool = false,
        link: DetectedMeetingLink? = nil
    ) -> CalendarMeeting {
        CalendarMeeting(
            eventID: id,
            title: title,
            start: now.addingTimeInterval(startOffset),
            end: now.addingTimeInterval(endOffset),
            isAllDay: isAllDay,
            isDeclined: isDeclined,
            link: link
        )
    }

    private var zoomLink: DetectedMeetingLink {
        DetectedMeetingLink(provider: .zoom, url: URL(string: "https://zoom.us/j/1")!)
    }

    func testLinkedActiveMeetingAutoPauses() {
        let m = meeting(link: zoomLink)
        let action = CalendarPauseCoordinator.decide(
            meetings: [m], now: now, currentlyPaused: false,
            actedKeys: [], suggestUnlinked: true
        )
        XCTAssertEqual(action, .autoPause(m))
    }

    func testUnlinkedActiveMeetingSuggestsWhenEnabled() {
        let m = meeting()
        let action = CalendarPauseCoordinator.decide(
            meetings: [m], now: now, currentlyPaused: false,
            actedKeys: [], suggestUnlinked: true
        )
        XCTAssertEqual(action, .suggest(m))
    }

    func testUnlinkedMeetingIsIgnoredWhenSuggestionsOff() {
        let m = meeting()
        let action = CalendarPauseCoordinator.decide(
            meetings: [m], now: now, currentlyPaused: false,
            actedKeys: [], suggestUnlinked: false
        )
        XCTAssertEqual(action, .none)
    }

    func testAllDayEventIsSkipped() {
        let m = meeting(isAllDay: true, link: zoomLink)
        let action = CalendarPauseCoordinator.decide(
            meetings: [m], now: now, currentlyPaused: false,
            actedKeys: [], suggestUnlinked: true
        )
        XCTAssertEqual(action, .none)
    }

    func testDeclinedEventIsSkipped() {
        let m = meeting(isDeclined: true, link: zoomLink)
        let action = CalendarPauseCoordinator.decide(
            meetings: [m], now: now, currentlyPaused: false,
            actedKeys: [], suggestUnlinked: true
        )
        XCTAssertEqual(action, .none)
    }

    func testAlreadyActedMeetingIsSkipped() {
        let m = meeting(link: zoomLink)
        let action = CalendarPauseCoordinator.decide(
            meetings: [m], now: now, currentlyPaused: false,
            actedKeys: [m.occurrenceKey], suggestUnlinked: true
        )
        XCTAssertEqual(action, .none)
    }

    func testExistingPauseIsNeverOverridden() {
        let m = meeting(link: zoomLink)
        let action = CalendarPauseCoordinator.decide(
            meetings: [m], now: now, currentlyPaused: true,
            actedKeys: [], suggestUnlinked: true
        )
        XCTAssertEqual(action, .none)
    }

    func testFutureMeetingIsNotYetActive() {
        let m = meeting(startOffset: 600, endOffset: 2400, link: zoomLink) // starts in 10m
        let action = CalendarPauseCoordinator.decide(
            meetings: [m], now: now, currentlyPaused: false,
            actedKeys: [], suggestUnlinked: true
        )
        XCTAssertEqual(action, .none)
    }

    /// When a linked and an unlinked meeting are both active, the linked one
    /// (auto-pause) is preferred over the unlinked suggestion.
    func testLinkedIsPreferredOverUnlinkedWhenOverlapping() {
        let linked = meeting(id: "linked", title: "Standup", startOffset: -60, link: zoomLink)
        let unlinked = meeting(id: "unlinked", title: "Desk work", startOffset: -600)
        let action = CalendarPauseCoordinator.decide(
            meetings: [unlinked, linked], now: now, currentlyPaused: false,
            actedKeys: [], suggestUnlinked: true
        )
        XCTAssertEqual(action, .autoPause(linked))
    }

    /// A link-less meeting is suggested BEFORE it starts (within the lead
    /// window) so the user has time to react.
    func testUnlinkedMeetingSuggestsBeforeStartWithinLead() {
        let m = meeting(startOffset: 90, endOffset: 1500) // starts in 90s
        let action = CalendarPauseCoordinator.decide(
            meetings: [m], now: now, currentlyPaused: false,
            actedKeys: [], suggestUnlinked: true, leadTime: 120
        )
        XCTAssertEqual(action, .suggest(m))
    }

    /// Beyond the lead window (event still >lead away) nothing is offered yet.
    func testUnlinkedMeetingNotSuggestedBeyondLead() {
        let m = meeting(startOffset: 180, endOffset: 1500) // starts in 3m
        let action = CalendarPauseCoordinator.decide(
            meetings: [m], now: now, currentlyPaused: false,
            actedKeys: [], suggestUnlinked: true, leadTime: 120
        )
        XCTAssertEqual(action, .none)
    }

    /// A linked meeting auto-pauses within the lead window too (consistent with
    /// suggestions) — the timer is paused before the meeting begins.
    func testLinkedMeetingAutoPausesEarlyWithinLead() {
        let m = meeting(startOffset: 90, endOffset: 1500, link: zoomLink) // starts in 90s
        let action = CalendarPauseCoordinator.decide(
            meetings: [m], now: now, currentlyPaused: false,
            actedKeys: [], suggestUnlinked: true, leadTime: 120
        )
        XCTAssertEqual(action, .autoPause(m))
    }

    /// Beyond the lead window a linked meeting isn't auto-paused yet.
    func testLinkedMeetingNotAutoPausedBeyondLead() {
        let m = meeting(startOffset: 180, endOffset: 1500, link: zoomLink) // starts in 3m
        let action = CalendarPauseCoordinator.decide(
            meetings: [m], now: now, currentlyPaused: false,
            actedKeys: [], suggestUnlinked: true, leadTime: 120
        )
        XCTAssertEqual(action, .none)
    }
}
