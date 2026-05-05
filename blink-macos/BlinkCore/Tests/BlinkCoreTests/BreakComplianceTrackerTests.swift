import Foundation
import Testing
@testable import BlinkCore

@Suite("BreakComplianceTracker")
struct BreakComplianceTrackerTests {
    @Test("Break taken within 60s = taken")
    func breakTaken() {
        let tracker = BreakComplianceTracker()
        var recorded: BreakRecord?
        tracker.onBreakRecorded = { recorded = $0 }

        let promptTime = Date()
        tracker.breakPrompted(at: promptTime, flowState: .normal, flowScore: 0.5)

        tracker.breakTaken(at: promptTime.addingTimeInterval(10), idleDuration: 20)

        #expect(recorded?.compliance == .taken)
    }

    @Test("Break dismissed quickly = dismissed")
    func breakDismissed() {
        let tracker = BreakComplianceTracker()
        var recorded: BreakRecord?
        tracker.onBreakRecorded = { recorded = $0 }

        let promptTime = Date()
        tracker.breakPrompted(at: promptTime, flowState: .normal, flowScore: 0.5)

        tracker.breakDismissed(at: promptTime.addingTimeInterval(2))

        #expect(recorded?.compliance == .dismissed)
    }

    @Test("Break dismissed after delay = delayed")
    func breakDelayed() {
        let tracker = BreakComplianceTracker()
        var recorded: BreakRecord?
        tracker.onBreakRecorded = { recorded = $0 }

        let promptTime = Date()
        tracker.breakPrompted(at: promptTime, flowState: .flow, flowScore: 0.8)

        tracker.breakDismissed(at: promptTime.addingTimeInterval(30))

        #expect(recorded?.compliance == .delayed)
    }

    @Test("Break ignored = ignored")
    func breakIgnored() {
        let tracker = BreakComplianceTracker()
        var recorded: BreakRecord?
        tracker.onBreakRecorded = { recorded = $0 }

        let promptTime = Date()
        tracker.breakPrompted(at: promptTime, flowState: .normal, flowScore: 0.3)

        tracker.breakIgnored(at: promptTime.addingTimeInterval(300))

        #expect(recorded?.compliance == .ignored)
        #expect(recorded?.respondedAt == nil)
    }

    @Test("No prompt = no record")
    func noPrompt() {
        let tracker = BreakComplianceTracker()
        var recorded: BreakRecord?
        tracker.onBreakRecorded = { recorded = $0 }

        tracker.breakTaken(at: Date(), idleDuration: 20)
        #expect(recorded == nil, "Should not record without a prompt")
    }

    @Test("isTrackingBreak reflects state")
    func trackingState() {
        let tracker = BreakComplianceTracker()
        #expect(!tracker.isTrackingBreak)

        tracker.breakPrompted(at: Date(), flowState: .normal, flowScore: 0.5)
        #expect(tracker.isTrackingBreak)

        tracker.breakTaken(at: Date(), idleDuration: 20)
        #expect(!tracker.isTrackingBreak)
    }

    @Test("Flow state and score are captured at prompt time")
    func capturesPromptState() {
        let tracker = BreakComplianceTracker()
        var recorded: BreakRecord?
        tracker.onBreakRecorded = { recorded = $0 }

        tracker.breakPrompted(at: Date(), flowState: .deepFlow, flowScore: 0.92)
        tracker.breakTaken(at: Date(), idleDuration: 20)

        #expect(recorded?.flowStateWhenPrompted == .deepFlow)
        #expect(recorded?.flowScore == 0.92)
    }
}
