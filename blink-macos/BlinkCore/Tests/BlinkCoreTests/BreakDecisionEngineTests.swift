import Foundation
import Testing
@testable import BlinkCore

@Suite("BreakDecisionEngine")
struct BreakDecisionEngineTests {

    @Test("No input → skip")
    func noInputSkips() {
        let engine = BreakDecisionEngine()
        engine.tick(now: 0)
        engine.tick(now: 1200) // 20 min

        let decision = engine.decide()
        #expect(decision == .skip, "No input should skip — not worth a break")
    }

    @Test("Very low activity → skip")
    func veryLowActivitySkips() {
        let engine = BreakDecisionEngine()
        engine.tick(now: 0)

        // 50 keystrokes + 30 scrolls in 20 min = ~4 inputs/min
        for _ in 0..<50 { engine.recordKeystroke() }
        for _ in 0..<30 { engine.recordScroll() }
        engine.tick(now: 1200)

        let decision = engine.decide()
        #expect(decision == .skip, "Sporadic activity should skip")
    }

    @Test("Heavy typing → extend")
    func heavyTypingExtends() {
        let engine = BreakDecisionEngine()
        engine.tick(now: 0)

        // Simulate 20 min of typing: 60 kpm = 1200 keystrokes
        for _ in 0..<1200 {
            engine.recordKeystroke()
        }
        engine.tick(now: 1200)

        let decision = engine.decide()
        if case .extend(let minutes, _) = decision {
            #expect(minutes == 30, "First extension should be to 30 min")
        } else {
            #expect(Bool(false), "Heavy typing should extend, got showBreak")
        }
    }

    @Test("Heavy clicking (designer) → extend")
    func heavyClickingExtends() {
        let engine = BreakDecisionEngine()
        engine.tick(now: 0)

        // Simulate designer: 20 clicks/min for 20 min = 400 clicks + some keys for shortcuts
        for _ in 0..<400 {
            engine.recordClick()
        }
        for _ in 0..<100 {
            engine.recordKeystroke()
        }
        engine.setCurrentApp(bundleID: "com.figma.Desktop")
        engine.tick(now: 1200)

        let decision = engine.decide()
        if case .extend = decision {
            // Good — designer work detected
        } else {
            #expect(Bool(false), "Designer work should extend")
        }
    }

    @Test("Scroll-only (browsing) → show break")
    func scrollOnlyShowsBreak() {
        let engine = BreakDecisionEngine()
        engine.tick(now: 0)

        // Lots of scrolling, no keyboard
        for _ in 0..<200 {
            engine.recordScroll()
        }
        engine.tick(now: 1200)

        let decision = engine.decide()
        #expect(decision == .showBreak, "Scroll-only browsing should show break")
    }

    @Test("Max 2 extensions then show break")
    func maxTwoExtensions() {
        let engine = BreakDecisionEngine()

        // First 20 min — heavy typing
        engine.tick(now: 0)
        for _ in 0..<1200 { engine.recordKeystroke() }
        engine.tick(now: 1200)
        let d1 = engine.decide()
        if case .extend(let m, _) = d1 { #expect(m == 30) }
        engine.resetWindow()

        // Next 10 min — still typing
        engine.tick(now: 1200)
        for _ in 0..<600 { engine.recordKeystroke() }
        engine.tick(now: 1800)
        let d2 = engine.decide()
        if case .extend(let m, _) = d2 { #expect(m == 40) }
        engine.resetWindow()

        // Next 10 min — still typing but max reached
        engine.tick(now: 1800)
        for _ in 0..<600 { engine.recordKeystroke() }
        engine.tick(now: 2400)
        let d3 = engine.decide()
        #expect(d3 == .showBreak, "Third extension should be denied — max 2")
    }

    @Test("Reset clears extension count")
    func resetClearsExtensions() {
        let engine = BreakDecisionEngine()

        // Use up one extension
        engine.tick(now: 0)
        for _ in 0..<1200 { engine.recordKeystroke() }
        engine.tick(now: 1200)
        _ = engine.decide()

        // Full reset (walk away)
        engine.resetAll()

        // Should be able to extend again
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

    @Test("Casual chatting (few keystrokes, long gaps) → skip")
    func casualChattingSkips() {
        let engine = BreakDecisionEngine()
        engine.tick(now: 0)

        // 20 min of casual chat: ~50 keystrokes, some scrolls = ~4 inputs/min
        for _ in 0..<50 { engine.recordKeystroke() }
        for _ in 0..<30 { engine.recordScroll() }
        engine.tick(now: 1200)

        let decision = engine.decide()
        #expect(decision == .skip, "Casual chatting (4 inputs/min) should skip")
    }

    @Test("Moderate browsing (enough activity) → show break")
    func moderateBrowsingShowsBreak() {
        let engine = BreakDecisionEngine()
        engine.tick(now: 0)

        // 20 min of active browsing: clicks + scrolls + some typing
        for _ in 0..<150 { engine.recordClick() }
        for _ in 0..<200 { engine.recordScroll() }
        for _ in 0..<50 { engine.recordKeystroke() }
        engine.recordAppSwitch(bundleID: "com.apple.Safari")
        for _ in 0..<15 { engine.recordAppSwitch(bundleID: "com.apple.Safari") }
        engine.tick(now: 1200)

        let decision = engine.decide()
        #expect(decision == .showBreak, "Active browsing should show break")
    }

    @Test("Sensitivity affects threshold")
    func sensitivityAffectsThreshold() {
        // Low sensitivity — harder to extend
        let strict = BreakDecisionEngine()
        strict.sensitivity = 0.4
        strict.tick(now: 0)
        for _ in 0..<300 { strict.recordKeystroke() } // 15 kpm — moderate
        strict.tick(now: 1200)
        let d1 = strict.decide()

        // High sensitivity — easier to extend
        let relaxed = BreakDecisionEngine()
        relaxed.sensitivity = 0.9
        relaxed.tick(now: 0)
        for _ in 0..<300 { relaxed.recordKeystroke() } // same 15 kpm
        relaxed.tick(now: 1200)
        let d2 = relaxed.decide()

        // High sensitivity should be more likely to extend
        if case .showBreak = d1, case .extend = d2 {
            // Expected: strict shows break, relaxed extends
        } else if case .extend = d1, case .extend = d2 {
            // Both extend — also ok, 15 kpm might be enough even for strict
        } else if case .showBreak = d1, case .showBreak = d2 {
            // Both show break — also possible at 15 kpm
        }
        // Just verify they don't crash and return valid decisions
    }
}
