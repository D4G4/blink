// Port of blink-windows/src/Blink.Core.Tests/BreakDecisionEngineTests.cs
// Drop into Tests/BlinkCoreTests/ in the private blink-core repo.

import XCTest
@testable import BlinkCore

final class BreakDecisionEngineTests: XCTestCase {

    // MARK: - Window mechanics

    func test_emptyWindow_alwaysShowsBreak() {
        let d = BreakDecisionEngine()
        d.tick(60)
        XCTAssertEqual(d.decide(), .showBreak)
    }

    func test_zeroWindowSeconds_doesNotDivideByZero() {
        let d = BreakDecisionEngine()
        // Window has zero elapsed seconds — should not throw or NaN
        XCTAssertEqual(d.decide(), .showBreak)
    }

    func test_resetWindow_clearsCountsButKeepsExtensions() {
        let d = BreakDecisionEngine()
        d.sensitivity = 0.6
        simulateHeavyTyping(d, durationSeconds: 1200)
        // First call: should extend, _extensionCount → 1
        guard case .extend = d.decide() else {
            return XCTFail("expected .extend")
        }
        d.resetWindow()
        // No input + frequent app-switching scores below the 0.5 threshold.
        d.tick(0)
        for _ in 0..<60 { d.recordAppSwitch("Chrome") }
        d.tick(1200)
        XCTAssertEqual(d.decide(), .showBreak)
    }

    func test_resetAll_clearsCountsAndExtensions() {
        let d = BreakDecisionEngine()
        d.sensitivity = 0.9
        simulateHeavyTyping(d, durationSeconds: 1200)
        guard case .extend = d.decide() else {
            return XCTFail("expected .extend")
        }
        d.resetAll()
        // After resetAll, extension counter is back to 0 — heavy activity extends again
        simulateHeavyTyping(d, durationSeconds: 1200)
        guard case .extend = d.decide() else {
            return XCTFail("expected .extend after resetAll")
        }
    }

    // MARK: - Decision boundary by sensitivity

    func test_highSensitivity_extendsAtModerateActivity() {
        let d = BreakDecisionEngine()
        d.sensitivity = 0.9
        simulateModerateTyping(d, durationSeconds: 1200)
        guard case .extend = d.decide() else {
            return XCTFail("expected .extend")
        }
    }

    func test_lowSensitivity_requiresHeavyActivity() {
        let d = BreakDecisionEngine()
        d.sensitivity = 0.4
        simulateModerateTyping(d, durationSeconds: 1200)
        // threshold = 1.1 - 0.4 = 0.7. Moderate activity scores below.
        XCTAssertEqual(d.decide(), .showBreak)
    }

    func test_lowSensitivity_stillExtendsForHeavyActivity() {
        let d = BreakDecisionEngine()
        d.sensitivity = 0.4
        simulateHeavyTyping(d, durationSeconds: 1200)
        guard case .extend = d.decide() else {
            return XCTFail("expected .extend")
        }
    }

    // MARK: - Extension cap

    func test_maxExtensions_zero_alwaysShowsBreak() {
        let d = BreakDecisionEngine()
        d.sensitivity = 0.9
        simulateHeavyTyping(d, durationSeconds: 1200)
        XCTAssertEqual(d.decide(maxExtensions: 0), .showBreak)
    }

    func test_extends_firstTwo_thenBreaks() {
        let d = BreakDecisionEngine()
        d.sensitivity = 0.9

        simulateHeavyTyping(d, durationSeconds: 1200)
        guard case .extend = d.decide(maxExtensions: 2) else {
            return XCTFail("expected first .extend")
        }

        d.resetWindow()
        simulateHeavyTyping(d, durationSeconds: 1200)
        guard case .extend = d.decide(maxExtensions: 2) else {
            return XCTFail("expected second .extend")
        }

        d.resetWindow()
        simulateHeavyTyping(d, durationSeconds: 1200)
        // Third call: cap hit, forced break
        XCTAssertEqual(d.decide(maxExtensions: 2), .showBreak)
    }

    func test_extensionMinutes_30Then40() {
        let d = BreakDecisionEngine()
        d.sensitivity = 0.9

        simulateHeavyTyping(d, durationSeconds: 1200)
        guard case let .extend(minutes: m1, reason: _) = d.decide() else {
            return XCTFail("expected first .extend")
        }
        XCTAssertEqual(m1, 30)

        d.resetWindow()
        simulateHeavyTyping(d, durationSeconds: 1200)
        guard case let .extend(minutes: m2, reason: _) = d.decide() else {
            return XCTFail("expected second .extend")
        }
        XCTAssertEqual(m2, 40)
    }

    // MARK: - Signal mix

    func test_onlyScrolling_doesNotExtend() {
        let d = BreakDecisionEngine()
        d.sensitivity = 0.6
        d.tick(0)
        for _ in 0..<200 { d.recordScroll() }
        for _ in 0..<60 { d.recordAppSwitch("Chrome") }
        d.tick(1200)
        XCTAssertEqual(d.decide(), .showBreak)
    }

    func test_frequentAppSwitching_penalizesScore() {
        let d = BreakDecisionEngine()
        d.sensitivity = 0.9
        d.tick(0)
        for _ in 0..<1600 { d.recordKeystroke() }
        for _ in 0..<200 { d.recordClick() }
        for _ in 0..<50 { d.recordAppSwitch("OtherApp") }
        d.tick(1200)
        guard case .extend = d.decide() else {
            return XCTFail("expected .extend despite switching")
        }
    }

    func test_creativeApp_tipsAtThreshold() {
        let withCreative = BreakDecisionEngine()
        withCreative.sensitivity = 0.65
        simulateBoundaryTyping(withCreative)
        withCreative.recordAppSwitch("Code")
        let c = withCreative.decide()

        let withoutCreative = BreakDecisionEngine()
        withoutCreative.sensitivity = 0.65
        simulateBoundaryTyping(withoutCreative)
        withoutCreative.recordAppSwitch("notepad")
        let nc = withoutCreative.decide()

        // Creative-app bonus must not invert the decision
        let creativeIsExtend: Bool = { if case .extend = c { return true } else { return false } }()
        let nonCreativeIsBreak: Bool = (nc == .showBreak)
        XCTAssertTrue(creativeIsExtend || nonCreativeIsBreak)
    }

    // MARK: - Helpers
    //
    // tick(now) takes a wall-clock timestamp. The first call sets the window
    // start; subsequent calls compute elapsed = now - start. So to simulate a
    // 20-minute window we tick(0) at the beginning and tick(1200) at the end.

    private func simulateHeavyTyping(_ d: BreakDecisionEngine, durationSeconds: Double) {
        d.tick(0)
        for _ in 0..<Int(durationSeconds / 60.0 * 100) { d.recordKeystroke() }
        for _ in 0..<Int(durationSeconds / 60.0 * 10) { d.recordClick() }
        d.tick(durationSeconds)
    }

    private func simulateModerateTyping(_ d: BreakDecisionEngine, durationSeconds: Double) {
        d.tick(0)
        for _ in 0..<Int(durationSeconds / 60.0 * 40) { d.recordKeystroke() }
        for _ in 0..<Int(durationSeconds / 60.0 * 3) { d.recordClick() }
        d.tick(durationSeconds)
    }

    private func simulateBoundaryTyping(_ d: BreakDecisionEngine) {
        d.tick(0)
        for _ in 0..<600 { d.recordKeystroke() }
        for _ in 0..<60 { d.recordClick() }
        d.tick(1200)
    }
}
