import Foundation
import Testing
@testable import BlinkCore

@Suite("AppSwitchScorer")
struct AppSwitchScorerTests {
    let scorer = AppSwitchScorer()

    @Test("No switches = max score")
    func noSwitches() {
        let score = scorer.score(switchTimestamps: [], now: 1000)
        #expect(score == 1.0)
    }

    @Test("1 switch = high score")
    func oneSwitch() {
        let score = scorer.score(switchTimestamps: [999], now: 1000)
        #expect(score == 0.85)
    }

    @Test("5+ switches = zero score")
    func manySwitches() {
        let timestamps = (0..<6).map { 900.0 + Double($0) * 10 }
        let score = scorer.score(switchTimestamps: timestamps, now: 1000)
        #expect(score == 0.0)
    }

    @Test("Old switches outside 5-min window are ignored")
    func oldSwitchesIgnored() {
        // Switches from 10 minutes ago
        let timestamps = (0..<10).map { 300.0 + Double($0) * 10 }
        let score = scorer.score(switchTimestamps: timestamps, now: 1000)
        #expect(score == 1.0, "Switches older than 5 min should be ignored")
    }
}
