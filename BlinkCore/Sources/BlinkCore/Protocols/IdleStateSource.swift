import Foundation

public protocol IdleStateSource {
    func secondsSinceLastInput() -> TimeInterval
}
