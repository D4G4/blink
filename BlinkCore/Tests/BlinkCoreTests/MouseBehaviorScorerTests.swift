import Foundation
import Testing
@testable import BlinkCore

@Suite("MouseBehaviorScorer")
struct MouseBehaviorScorerTests {
    let scorer = MouseBehaviorScorer()

    @Test("No input = neutral score")
    func noInput() {
        let score = scorer.score(mouseEvents: [], keystrokeCount: 0, now: 1000)
        #expect(score == 0.5)
    }

    @Test("Keyboard only = high score")
    func keyboardOnly() {
        let score = scorer.score(mouseEvents: [], keystrokeCount: 50, now: 1000)
        #expect(score > 0.9, "Keyboard-dominant should be high score, got \(score)")
    }

    @Test("Mouse only = low score")
    func mouseOnly() {
        let events = (0..<20).map { MouseEvent(timestamp: 940 + Double($0) * 3, kind: .click) }
        let score = scorer.score(mouseEvents: events, keystrokeCount: 0, now: 1000)
        #expect(score < 0.2, "Mouse-only should be low score, got \(score)")
    }

    @Test("Heavy scrolling no typing = browsing")
    func heavyScrolling() {
        let events = (0..<25).map { MouseEvent(timestamp: 940 + Double($0) * 2, kind: .scroll(deltaY: 10)) }
        let score = scorer.score(mouseEvents: events, keystrokeCount: 2, now: 1000)
        #expect(score < 0.2, "Heavy scrolling with no typing = browsing, got \(score)")
    }
}
