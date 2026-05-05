import Foundation
import Testing
@testable import BlinkCore

@Suite("FlowScoreCalculator")
struct FlowScoreCalculatorTests {
    let calculator = FlowScoreCalculator()

    @Test("No input produces low score")
    func noInput() {
        let score = calculator.currentScore(now: 1000)
        // With no input, keystroke=0, mouse=0.5 (neutral), app switch=1.0, window=1.0, context=0.5
        // 0.35*1.0 + 0.25*0 + 0.20*0.5 + 0.10*1.0 + 0.10*0.5 = 0.35+0+0.1+0.1+0.05 = 0.6
        #expect(score < 0.65)
        #expect(score > 0.4)
    }

    @Test("Sustained typing produces high score")
    func sustainedTyping() {
        let now: TimeInterval = 1000

        // Simulate 60 keystrokes over 60 seconds (1 KPS = 60 KPM), steady rhythm
        for i in 0..<60 {
            calculator.ingestKeystroke(KeystrokeEvent(timestamp: now - 60 + Double(i)))
        }

        // Set a creative app
        calculator.setCurrentApp(bundleID: "com.apple.dt.Xcode")

        let score = calculator.currentScore(now: now)
        #expect(score > 0.6, "Sustained typing in Xcode should produce a high flow score, got \(score)")
    }

    @Test("Lots of app switching produces low score")
    func frequentAppSwitching() {
        let now: TimeInterval = 1000

        // 8 app switches in last 5 minutes
        for i in 0..<8 {
            calculator.recordAppSwitch(AppSwitchEvent(
                timestamp: now - 250 + Double(i) * 30,
                appBundleID: "com.app.\(i)"
            ))
        }

        let score = calculator.currentScore(now: now)
        #expect(score < 0.5, "Heavy app switching should reduce flow score, got \(score)")
    }

    @Test("Heavy scrolling with no typing = browsing")
    func scrollingBrowsing() {
        let now: TimeInterval = 1000

        // 30 scroll events, no keystrokes
        for i in 0..<30 {
            calculator.ingestMouseEvent(MouseEvent(
                timestamp: now - 60 + Double(i) * 2,
                kind: .scroll(deltaY: 10)
            ))
        }

        let score = calculator.currentScore(now: now)
        #expect(score < 0.55, "Scrolling without typing should indicate browsing, got \(score)")
    }

    @Test("Creative app bonus")
    func creativeAppBonus() {
        let now: TimeInterval = 1000

        // Same typing pattern
        for i in 0..<30 {
            calculator.ingestKeystroke(KeystrokeEvent(timestamp: now - 60 + Double(i) * 2))
        }

        calculator.setCurrentApp(bundleID: "com.apple.dt.Xcode")
        let xcodeScore = calculator.currentScore(now: now)

        let calculator2 = FlowScoreCalculator()
        for i in 0..<30 {
            calculator2.ingestKeystroke(KeystrokeEvent(timestamp: now - 60 + Double(i) * 2))
        }
        calculator2.setCurrentApp(bundleID: "com.tinyspeck.slackmacgap")
        let slackScore = calculator2.currentScore(now: now)

        #expect(xcodeScore > slackScore, "Xcode (\(xcodeScore)) should score higher than Slack (\(slackScore))")
    }
}
