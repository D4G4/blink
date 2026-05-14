import Foundation

public protocol IdleStateSource {
    /// Time since any input (keyboard, mouse move, scroll, click). Used for idle detection.
    func secondsSinceLastInput() -> TimeInterval
    /// Time since last intentional input (keyboard + clicks + scroll, NOT mouse moves).
    /// Used for flow detection in V3.
    func secondsSinceLastIntentionalInput() -> TimeInterval
    /// Time since last keystroke. Used for breakpoint detection.
    func secondsSinceLastKeystroke() -> TimeInterval
    /// Time since last mouse click. Used for breakpoint detection.
    func secondsSinceLastClick() -> TimeInterval
    /// Time since last scroll. Used for breakpoint detection.
    func secondsSinceLastScroll() -> TimeInterval
}
