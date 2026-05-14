import Foundation
import CoreGraphics
import BlinkCore

/// Detects system idle time using CGEventSource.
final class MacIdleDetector: IdleStateSource {
    /// Time since any input — keyboard, mouse move, click, scroll.
    func secondsSinceLastInput() -> TimeInterval {
        min(secondsSinceLastKeystroke(),
            secondsSinceLastMouseMove(),
            secondsSinceLastClick(),
            secondsSinceLastScroll())
    }

    /// Time since last intentional input — keyboard, clicks, scroll (NOT mouse moves).
    func secondsSinceLastIntentionalInput() -> TimeInterval {
        min(secondsSinceLastKeystroke(),
            secondsSinceLastClick(),
            secondsSinceLastScroll())
    }

    func secondsSinceLastKeystroke() -> TimeInterval {
        CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .keyDown)
    }

    func secondsSinceLastClick() -> TimeInterval {
        CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .leftMouseDown)
    }

    func secondsSinceLastScroll() -> TimeInterval {
        CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .scrollWheel)
    }

    private func secondsSinceLastMouseMove() -> TimeInterval {
        CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .mouseMoved)
    }
}
