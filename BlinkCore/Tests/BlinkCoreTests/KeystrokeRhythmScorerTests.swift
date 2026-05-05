import Foundation
import Testing
@testable import BlinkCore

@Suite("KeystrokeRhythmScorer")
struct KeystrokeRhythmScorerTests {
    let scorer = KeystrokeRhythmScorer()

    @Test("No keystrokes = zero score")
    func noKeystrokes() {
        let score = scorer.score(keystrokeTimestamps: [], now: 1000)
        #expect(score == 0.0)
    }

    @Test("Too few keystrokes = zero score")
    func tooFew() {
        let score = scorer.score(keystrokeTimestamps: [998, 999, 1000], now: 1000)
        #expect(score == 0.0, "Fewer than 5 keystrokes should score 0")
    }

    @Test("Steady rhythmic typing = high score")
    func steadyTyping() {
        // 60 keystrokes, 1 per second, very rhythmic
        let timestamps = (0..<60).map { 940.0 + Double($0) }
        let score = scorer.score(keystrokeTimestamps: timestamps, now: 1000)
        #expect(score > 0.5, "Steady typing should produce a decent score, got \(score)")
    }

    @Test("Old keystrokes outside 2-min window are ignored")
    func oldKeystrokesIgnored() {
        // All keystrokes from 5 minutes ago
        let timestamps = (0..<30).map { 600.0 + Double($0) }
        let score = scorer.score(keystrokeTimestamps: timestamps, now: 1000)
        #expect(score == 0.0, "Old keystrokes should be ignored")
    }
}
