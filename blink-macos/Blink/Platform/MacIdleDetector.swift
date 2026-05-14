import Foundation
import CoreGraphics
import BlinkCore

/// Detects system idle time using CGEventSource.
final class MacIdleDetector: IdleStateSource {
    /// Time since any input — keyboard, mouse move, click, scroll.
    /// Used for idle/walk-away detection.
    func secondsSinceLastInput() -> TimeInterval {
        let keyboardIdle = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .keyDown)
        let mouseIdle = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .mouseMoved)
        let clickIdle = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .leftMouseDown)
        let scrollIdle = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .scrollWheel)
        return min(keyboardIdle, mouseIdle, clickIdle, scrollIdle)
    }

    /// Time since last intentional input — keyboard, clicks, scroll (NOT mouse moves).
    /// Used for flow detection in V3. Mouse moves are ambient and constant.
    func secondsSinceLastIntentionalInput() -> TimeInterval {
        let keyboardIdle = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .keyDown)
        let clickIdle = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .leftMouseDown)
        let scrollIdle = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .scrollWheel)
        return min(keyboardIdle, clickIdle, scrollIdle)
    }
}
