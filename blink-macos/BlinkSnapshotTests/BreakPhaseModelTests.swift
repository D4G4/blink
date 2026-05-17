import XCTest
@testable import Blink

final class BreakPhaseModelTests: XCTestCase {

    func testCountdownReachesZeroCallsOnComplete() {
        let model = BreakPhaseModel()
        model.remaining = 3  // short countdown for testing
        model.total = 3

        let expectation = expectation(description: "onComplete fires when countdown reaches 0")

        model.startTimer {
            expectation.fulfill()
        }

        waitForExpectations(timeout: 5) { error in
            XCTAssertNil(error, "onComplete should fire within 5 seconds")
            XCTAssertEqual(model.remaining, 0, "Remaining should be 0")
            XCTAssertNil(model.timer, "Timer should be stopped")
        }
    }

    func testCountdownDecrementsByOne() {
        let model = BreakPhaseModel()
        model.remaining = 10
        model.total = 10

        model.startTimer {}

        let expectation = expectation(description: "Wait 2 ticks")
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            expectation.fulfill()
        }

        waitForExpectations(timeout: 4)
        XCTAssertEqual(model.remaining, 8, "Should decrement by 1 each second (10 → 8 after ~2s)")
        model.stopTimer()
    }

    func testExtendAdds20Seconds() {
        let model = BreakPhaseModel()
        model.remaining = 5
        model.total = 20

        model.extend()

        XCTAssertEqual(model.remaining, 25, "Extend should add 20 to remaining")
        XCTAssertEqual(model.total, 40, "Extend should add 20 to total")
    }

    func testStopTimerPreventsCompletion() {
        let model = BreakPhaseModel()
        model.remaining = 2
        model.total = 2

        var completed = false
        model.startTimer { completed = true }

        // Stop before it can fire
        model.stopTimer()

        let expectation = expectation(description: "Wait to confirm no fire")
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            expectation.fulfill()
        }

        waitForExpectations(timeout: 4)
        XCTAssertFalse(completed, "Stopped timer should not fire onComplete")
    }
}
