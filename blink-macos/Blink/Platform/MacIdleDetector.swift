import Foundation
import CoreGraphics
import BlinkCore

/// Detects system idle time using CGEventSource.
final class MacIdleDetector: IdleStateSource {
    func secondsSinceLastInput() -> TimeInterval {
        let keyboardIdle = CGEventSource.secondsSinceLastEventType(
            .combinedSessionState,
            eventType: .keyDown
        )
        let mouseIdle = CGEventSource.secondsSinceLastEventType(
            .combinedSessionState,
            eventType: .mouseMoved
        )
        let clickIdle = CGEventSource.secondsSinceLastEventType(
            .combinedSessionState,
            eventType: .leftMouseDown
        )
        let scrollIdle = CGEventSource.secondsSinceLastEventType(
            .combinedSessionState,
            eventType: .scrollWheel
        )

        // Return the minimum — most recent activity of any kind
        return min(keyboardIdle, mouseIdle, clickIdle, scrollIdle)
    }
}
