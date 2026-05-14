import Foundation

public protocol IdleStateSource {
    /// Time since any input (keyboard, mouse move, scroll, click). Used for idle detection.
    func secondsSinceLastInput() -> TimeInterval
    /// Time since last intentional input (keyboard + clicks + scroll, NOT mouse moves).
    /// Used for flow detection in V3. Mouse moves are ambient and don't indicate work.
    func secondsSinceLastIntentionalInput() -> TimeInterval
}
