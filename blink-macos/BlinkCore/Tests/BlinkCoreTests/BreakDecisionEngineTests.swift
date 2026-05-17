import Foundation
import Testing
@testable import BlinkCore

@Suite("BreakDecisionEngine")
struct BreakDecisionEngineTests {

    @Test("No input → show break (no skip)")
    func noInputShowsBreak() {
        let engine = BreakDecisionEngine()
        engine.tick(now: 0)
        engine.tick(now: 1200)

        let decision = engine.decide()
        #expect(decision == .showBreak, "No input should show break — no silent skips")
    }

    @Test("Low activity → show break (no nudge)")
    func lowActivityShowsBreak() {
        let engine = BreakDecisionEngine()
        engine.tick(now: 0)

        // 50 keystrokes + 30 scrolls in 20 min = ~4 inputs/min
        for _ in 0..<50 { engine.recordKeystroke() }
        for _ in 0..<30 { engine.recordScroll() }
        engine.tick(now: 1200)

        let decision = engine.decide()
        #expect(decision == .showBreak, "Low activity should show break — eyes still strain")
    }

    @Test("Heavy typing → extend")
    func heavyTypingExtends() {
        let engine = BreakDecisionEngine()
        engine.tick(now: 0)

        for _ in 0..<1200 { engine.recordKeystroke() }
        engine.tick(now: 1200)

        let decision = engine.decide()
        if case .extend(let minutes, _) = decision {
            #expect(minutes == 30, "First extension should be to 30 min")
        } else {
            #expect(Bool(false), "Heavy typing should extend")
        }
    }

    @Test("Eye Health (maxExtensions=0) → always show break")
    func eyeHealthAlwaysBreaks() {
        let engine = BreakDecisionEngine()
        engine.tick(now: 0)

        // Heavy typing that would normally extend
        for _ in 0..<1200 { engine.recordKeystroke() }
        engine.tick(now: 1200)

        let decision = engine.decide(maxExtensions: 0)
        #expect(decision == .showBreak, "Eye Health should always show break")
    }

    @Test("Max extensions then show break")
    func maxExtensions() {
        let engine = BreakDecisionEngine()

        // First 20 min
        engine.tick(now: 0)
        for _ in 0..<1200 { engine.recordKeystroke() }
        engine.tick(now: 1200)
        let d1 = engine.decide(maxExtensions: 1)
        if case .extend(let m, _) = d1 { #expect(m == 30) }
        engine.resetWindow()

        // Next 10 min — still typing but max reached
        engine.tick(now: 1200)
        for _ in 0..<600 { engine.recordKeystroke() }
        engine.tick(now: 1800)
        let d2 = engine.decide(maxExtensions: 1)
        #expect(d2 == .showBreak, "Should show break after max extensions used")
    }

    @Test("Reset clears extension count")
    func resetClearsExtensions() {
        let engine = BreakDecisionEngine()

        engine.tick(now: 0)
        for _ in 0..<1200 { engine.recordKeystroke() }
        engine.tick(now: 1200)
        _ = engine.decide()

        engine.resetAll()

        engine.tick(now: 2000)
        for _ in 0..<1200 { engine.recordKeystroke() }
        engine.tick(now: 3200)
        let decision = engine.decide()
        if case .extend(let m, _) = decision {
            #expect(m == 30, "After reset, first extension should be to 30")
        } else {
            #expect(Bool(false), "Should extend after full reset")
        }
    }

    @Test("Scroll-only (browsing) → show break")
    func scrollOnlyShowsBreak() {
        let engine = BreakDecisionEngine()
        engine.tick(now: 0)

        for _ in 0..<200 { engine.recordScroll() }
        engine.tick(now: 1200)

        let decision = engine.decide()
        #expect(decision == .showBreak, "Scroll-only browsing should show break")
    }
}
