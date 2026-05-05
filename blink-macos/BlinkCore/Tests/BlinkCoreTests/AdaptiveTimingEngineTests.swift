import Foundation
import Testing
@testable import BlinkCore

@Suite("AdaptiveTimingEngine")
struct AdaptiveTimingEngineTests {
    @Test("Not enough data = no suggestion")
    func notEnoughData() {
        let engine = AdaptiveTimingEngine()
        for _ in 0..<5 {
            engine.recordAcceptedBreak(intervalSinceLastBreak: 1200)
        }
        #expect(engine.suggestedDuration() == nil, "Need 10+ data points")
    }

    @Test("10+ data points = median suggestion")
    func enoughData() {
        let engine = AdaptiveTimingEngine()
        let intervals: [TimeInterval] = [1200, 1300, 1100, 1400, 1250, 1350, 1150, 1500, 1200, 1300]
        for i in intervals {
            engine.recordAcceptedBreak(intervalSinceLastBreak: i)
        }
        let suggested = engine.suggestedDuration()
        #expect(suggested != nil)
        #expect(suggested! >= 900, "Should be at least 15 min")
        #expect(suggested! <= 2700, "Should be at most 45 min")
    }

    @Test("Clamps to min/max")
    func clamping() {
        let engine = AdaptiveTimingEngine()
        // All very short intervals
        for _ in 0..<15 {
            engine.recordAcceptedBreak(intervalSinceLastBreak: 300) // 5 min
        }
        #expect(engine.suggestedDuration() == 900, "Should clamp to 15 min minimum")

        let engine2 = AdaptiveTimingEngine()
        for _ in 0..<15 {
            engine2.recordAcceptedBreak(intervalSinceLastBreak: 5000) // 83 min
        }
        #expect(engine2.suggestedDuration() == 2700, "Should clamp to 45 min maximum")
    }

    @Test("Load and save round-trips")
    func loadSave() {
        let engine = AdaptiveTimingEngine()
        for i in 0..<12 {
            engine.recordAcceptedBreak(intervalSinceLastBreak: 1200 + Double(i) * 10)
        }
        let saved = engine.savedIntervals()

        let engine2 = AdaptiveTimingEngine()
        engine2.load(intervals: saved)
        #expect(engine2.suggestedDuration() == engine.suggestedDuration())
    }

    @Test("Buffer caps at 50 entries")
    func bufferCap() {
        let engine = AdaptiveTimingEngine()
        for i in 0..<60 {
            engine.recordAcceptedBreak(intervalSinceLastBreak: 1200 + Double(i))
        }
        #expect(engine.savedIntervals().count == 50)
    }
}
