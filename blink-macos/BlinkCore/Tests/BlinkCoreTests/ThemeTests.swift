import Foundation
import Testing
@testable import BlinkCore

// These test the theme data model — since BlinkTheme is in the app target,
// we test the core invariants that theme depends on here.

@Suite("Core data model safety")
struct CoreModelTests {
    @Test("FlowState is codable and roundtrips")
    func flowStateCodable() throws {
        for state in [FlowState.normal, .flow, .deepFlow, .idle, .meeting, .breakPrompted] {
            let data = try JSONEncoder().encode(state)
            let decoded = try JSONDecoder().decode(FlowState.self, from: data)
            #expect(decoded == state)
        }
    }

    @Test("BreakRecord is codable and roundtrips")
    func breakRecordCodable() throws {
        let record = BreakRecord(
            promptedAt: Date(),
            respondedAt: Date(),
            flowStateWhenPrompted: .flow,
            flowScore: 0.85,
            compliance: .taken,
            breakDurationSeconds: 20
        )
        let data = try JSONEncoder().encode(record)
        let decoded = try JSONDecoder().decode(BreakRecord.self, from: data)
        #expect(decoded.compliance == .taken)
        #expect(decoded.flowStateWhenPrompted == .flow)
        #expect(decoded.flowScore == 0.85)
    }

    @Test("BreakCompliance all cases are codable")
    func complianceCodable() throws {
        for c in [BreakCompliance.taken, .dismissed, .delayed, .ignored] {
            let data = try JSONEncoder().encode(c)
            let decoded = try JSONDecoder().decode(BreakCompliance.self, from: data)
            #expect(decoded == c)
        }
    }

    @Test("TimerStateMachine default constants are sane")
    func timerDefaults() {
        #expect(TimerStateMachine.defaultNormalDuration == 1200)
        #expect(TimerStateMachine.defaultFlowDuration == 1800)
        #expect(TimerStateMachine.defaultDeepFlowDuration == 2400)
        #expect(TimerStateMachine.defaultNormalDuration < TimerStateMachine.defaultFlowDuration)
        #expect(TimerStateMachine.defaultFlowDuration < TimerStateMachine.defaultDeepFlowDuration)
    }

    @Test("FlowStateMachine default constants are sane")
    func flowDefaults() {
        let sm = FlowStateMachine()
        #expect(sm.flowEntryDuration > 0)
        #expect(sm.flowExitDuration > 0)
        #expect(sm.deepFlowDuration > sm.flowEntryDuration)
        #expect(sm.idleThreshold > 0)
        #expect(sm.config.gapTolerance > 0)
    }

    @Test("FlowScoreCalculator reset clears all state")
    func calculatorReset() {
        let calc = FlowScoreCalculator()
        // Feed data
        for i in 0..<20 {
            calc.ingestKeystroke(KeystrokeEvent(timestamp: 900 + Double(i)))
        }
        calc.setCurrentApp(bundleID: "com.apple.dt.Xcode")

        let scoreBefore = calc.currentScore(now: 1000)
        #expect(scoreBefore > 0)

        calc.reset()
        let scoreAfter = calc.currentScore(now: 1000)

        // After reset, score should be lower (no keystroke data)
        #expect(scoreAfter < scoreBefore, "Reset should clear data")
    }
}
