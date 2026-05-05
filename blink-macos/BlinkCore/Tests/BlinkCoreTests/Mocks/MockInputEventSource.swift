import Foundation
@testable import BlinkCore

final class MockInputEventSource: InputEventSource {
    var onKeystroke: ((KeystrokeEvent) -> Void)?
    var onMouseEvent: ((MouseEvent) -> Void)?

    func startMonitoring() {}
    func stopMonitoring() {}

    func simulateKeystroke(at timestamp: TimeInterval) {
        onKeystroke?(KeystrokeEvent(timestamp: timestamp))
    }

    func simulateMouseMove(at timestamp: TimeInterval, dx: Double = 1, dy: Double = 1) {
        onMouseEvent?(MouseEvent(timestamp: timestamp, kind: .move(deltaX: dx, deltaY: dy)))
    }

    func simulateScroll(at timestamp: TimeInterval) {
        onMouseEvent?(MouseEvent(timestamp: timestamp, kind: .scroll(deltaY: 10)))
    }

    func simulateClick(at timestamp: TimeInterval) {
        onMouseEvent?(MouseEvent(timestamp: timestamp, kind: .click))
    }
}
