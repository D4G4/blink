import XCTest
@testable import Blink

/// Pure-logic tests for the meeting-link scanner. Plain XCTest (app-target
/// logic that can't live in the EventKit-free BlinkCore package).
final class MeetingLinkDetectorTests: XCTestCase {

    func testZoomInURLField() {
        let hit = MeetingLinkDetector.detect(
            urlString: "https://us05web.zoom.us/j/123456789",
            notes: nil, location: nil
        )
        XCTAssertEqual(hit?.provider, .zoom)
    }

    func testGoogleMeetInNotes() {
        let hit = MeetingLinkDetector.detect(
            urlString: nil,
            notes: "Join here: https://meet.google.com/abc-defg-hij\nAgenda below.",
            location: nil
        )
        XCTAssertEqual(hit?.provider, .googleMeet)
    }

    func testTeamsInLocation() {
        let hit = MeetingLinkDetector.detect(
            urlString: nil, notes: nil,
            location: "https://teams.microsoft.com/l/meetup-join/xyz"
        )
        XCTAssertEqual(hit?.provider, .teams)
    }

    func testWebex() {
        let hit = MeetingLinkDetector.detect(
            urlString: "https://acme.webex.com/meet/room", notes: nil, location: nil
        )
        XCTAssertEqual(hit?.provider, .webex)
    }

    func testNoLinkReturnsNil() {
        let hit = MeetingLinkDetector.detect(
            urlString: nil,
            notes: "1:1 sync — bring your updates. Room 4B.",
            location: "Room 4B"
        )
        XCTAssertNil(hit)
    }

    /// `zoominfo.com` must NOT match the `zoom.us` rule — host matching, not a
    /// naive substring scan.
    func testZoomInfoIsNotAMeetingLink() {
        let hit = MeetingLinkDetector.detect(
            urlString: "https://www.zoominfo.com/c/acme", notes: nil, location: nil
        )
        XCTAssertNil(hit)
    }

    /// A scheme-less link pasted into notes still resolves via the fallback.
    func testSchemelessZoomInNotes() {
        let hit = MeetingLinkDetector.detect(
            urlString: nil, notes: "dial in: zoom.us/j/987654321", location: nil
        )
        XCTAssertEqual(hit?.provider, .zoom)
    }

    /// The structured URL field wins over a link buried in notes.
    func testURLFieldTakesPriority() {
        let hit = MeetingLinkDetector.detect(
            urlString: "https://zoom.us/j/111",
            notes: "backup: https://meet.google.com/xyz",
            location: nil
        )
        XCTAssertEqual(hit?.provider, .zoom)
    }
}
