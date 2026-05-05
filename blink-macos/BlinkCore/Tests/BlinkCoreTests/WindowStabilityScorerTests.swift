import Foundation
import Testing
@testable import BlinkCore

@Suite("WindowStabilityScorer")
struct WindowStabilityScorerTests {
    let scorer = WindowStabilityScorer()

    @Test("No title changes = max score")
    func noChanges() {
        let score = scorer.score(titleChangeTimestamps: [], now: 1000)
        #expect(score == 1.0)
    }

    @Test("10+ changes = zero score")
    func manyChanges() {
        let timestamps = (0..<12).map { 800.0 + Double($0) * 20 }
        let score = scorer.score(titleChangeTimestamps: timestamps, now: 1000)
        #expect(score == 0.0)
    }

    @Test("5 changes = mid score")
    func midChanges() {
        let timestamps = (0..<5).map { 800.0 + Double($0) * 30 }
        let score = scorer.score(titleChangeTimestamps: timestamps, now: 1000)
        #expect(score == 0.5)
    }

    @Test("Old changes outside 5-min window are ignored")
    func oldChangesIgnored() {
        let timestamps = (0..<10).map { 300.0 + Double($0) * 10 }
        let score = scorer.score(titleChangeTimestamps: timestamps, now: 1000)
        #expect(score == 1.0)
    }
}
