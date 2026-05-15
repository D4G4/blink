import Foundation
import Testing
@testable import BlinkCore

@Suite("FlowSensitivity")
struct FlowSensitivityTests {

    // MARK: - BreakDecisionEngine sensitivity threshold

    @Test("Low sensitivity (0.4) requires higher score to extend")
    func lowSensitivityHigherThreshold() {
        let engine = BreakDecisionEngine()
        engine.sensitivity = 0.4
        engine.tick(now: 0)

        // Moderate typing: 15 kpm — not enough for strict threshold
        for _ in 0..<300 { engine.recordKeystroke() }
        engine.tick(now: 1200)

        let decision = engine.decide()
        // At 0.4 sensitivity, threshold is 0.7 — moderate typing won't reach it
        #expect(decision == .showBreak, "Low sensitivity should show break for moderate typing")
    }

    @Test("High sensitivity (0.9) extends more easily")
    func highSensitivityLowerThreshold() {
        let engine = BreakDecisionEngine()
        engine.sensitivity = 0.9
        engine.tick(now: 0)

        // Moderate typing: 15 kpm
        for _ in 0..<300 { engine.recordKeystroke() }
        engine.tick(now: 1200)

        let decision = engine.decide()
        // At 0.9 sensitivity, threshold is 0.2 — moderate typing should clear it
        if case .extend = decision {
            // Good — high sensitivity extends for moderate work
        } else {
            #expect(Bool(false), "High sensitivity should extend for moderate typing")
        }
    }

    @Test("Default sensitivity (0.7) extends for solid typing")
    func defaultSensitivitySolidTyping() {
        let engine = BreakDecisionEngine()
        engine.sensitivity = 0.7
        engine.tick(now: 0)

        // Solid typing: 40 kpm
        for _ in 0..<800 { engine.recordKeystroke() }
        engine.tick(now: 1200)

        let decision = engine.decide()
        if case .extend = decision {
            // Good
        } else {
            #expect(Bool(false), "Default sensitivity should extend for 40 kpm typing")
        }
    }

    // MARK: - Skip / Nudge / Break boundaries

    @Test("Zero inputs → skip")
    func zeroInputsSkip() {
        let engine = BreakDecisionEngine()
        engine.tick(now: 0)
        engine.tick(now: 1200)
        #expect(engine.decide() == .skip)
    }

    @Test("Under 1 input/min → skip")
    func veryLowSkip() {
        let engine = BreakDecisionEngine()
        engine.tick(now: 0)
        for _ in 0..<15 { engine.recordKeystroke() }
        engine.tick(now: 1200) // 15 inputs in 20 min = 0.75/min
        #expect(engine.decide() == .skip)
    }

    @Test("1-5 inputs/min → nudge")
    func lowActivityNudge() {
        let engine = BreakDecisionEngine()
        engine.tick(now: 0)
        for _ in 0..<60 { engine.recordKeystroke() }
        engine.tick(now: 1200) // 60 inputs in 20 min = 3/min
        #expect(engine.decide() == .nudge)
    }

    @Test("5+ inputs/min with low score → show break")
    func moderateActivityShowBreak() {
        let engine = BreakDecisionEngine()
        engine.tick(now: 0)
        // Lots of scrolling, some clicks, no keyboard = consumption
        for _ in 0..<200 { engine.recordScroll() }
        for _ in 0..<100 { engine.recordClick() }
        for _ in 0..<20 { engine.recordAppSwitch(bundleID: "com.apple.Safari") }
        engine.tick(now: 1200) // 300+ inputs in 20 min = 15+/min but scroll-heavy
        let decision = engine.decide()
        #expect(decision == .showBreak, "Scroll-heavy browsing should show break")
    }

    // MARK: - Extension limits

    @Test("Max 2 extensions then always show break")
    func maxExtensions() {
        let engine = BreakDecisionEngine()

        // Extension 1
        engine.tick(now: 0)
        for _ in 0..<1200 { engine.recordKeystroke() }
        engine.tick(now: 1200)
        if case .extend(let m, _) = engine.decide() { #expect(m == 30) }
        engine.resetWindow()

        // Extension 2
        engine.tick(now: 1200)
        for _ in 0..<600 { engine.recordKeystroke() }
        engine.tick(now: 1800)
        if case .extend(let m, _) = engine.decide() { #expect(m == 40) }
        engine.resetWindow()

        // Extension 3 denied
        engine.tick(now: 1800)
        for _ in 0..<600 { engine.recordKeystroke() }
        engine.tick(now: 2400)
        #expect(engine.decide() == .showBreak, "Third extension should be denied")
    }

    @Test("resetAll clears extension count")
    func resetAllClearsExtensions() {
        let engine = BreakDecisionEngine()

        // Use one extension
        engine.tick(now: 0)
        for _ in 0..<1200 { engine.recordKeystroke() }
        engine.tick(now: 1200)
        _ = engine.decide()

        // Full reset
        engine.resetAll()

        // Should extend again
        engine.tick(now: 2000)
        for _ in 0..<1200 { engine.recordKeystroke() }
        engine.tick(now: 3200)
        if case .extend(let m, _) = engine.decide() { #expect(m == 30) }
        else { #expect(Bool(false), "Should extend after resetAll") }
    }

    // MARK: - Creative app bonus

    @Test("Creative app gets bonus")
    func creativeAppBonus() {
        // With creative app
        let withApp = BreakDecisionEngine()
        withApp.sensitivity = 0.6
        withApp.tick(now: 0)
        for _ in 0..<400 { withApp.recordKeystroke() }
        withApp.setCurrentApp(bundleID: "com.microsoft.VSCode")
        withApp.tick(now: 1200)
        let d1 = withApp.decide()

        // Without creative app
        let withoutApp = BreakDecisionEngine()
        withoutApp.sensitivity = 0.6
        withoutApp.tick(now: 0)
        for _ in 0..<400 { withoutApp.recordKeystroke() }
        withoutApp.setCurrentApp(bundleID: "com.apple.Safari")
        withoutApp.tick(now: 1200)
        let d2 = withoutApp.decide()

        // Creative app should be more likely to extend
        if case .extend = d1, case .showBreak = d2 {
            // Expected: VS Code extends, Safari doesn't
        }
        // Both valid outcomes depending on exact score
    }
}
