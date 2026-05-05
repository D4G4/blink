import Foundation

/// Scores flow based on mouse behavior patterns.
/// Keyboard-dominant input = higher score (deep work). Weight: 0.20
public struct MouseBehaviorScorer: Sendable {
    private static let windowSeconds: TimeInterval = 120 // 2 minutes

    public init() {}

    /// Returns a score from 0.0 (mouse-heavy browsing) to 1.0 (keyboard-focused work).
    public func score(
        mouseEvents: [MouseEvent],
        keystrokeCount: Int,
        now: TimeInterval
    ) -> Double {
        let windowStart = now - Self.windowSeconds
        let recentMouse = mouseEvents.filter { $0.timestamp > windowStart }

        let scrollCount = recentMouse.filter {
            if case .scroll = $0.kind { return true }
            return false
        }.count

        let clickCount = recentMouse.filter {
            if case .click = $0.kind { return true }
            return false
        }.count

        let moveCount = recentMouse.filter {
            if case .move = $0.kind { return true }
            return false
        }.count

        let totalMouse = scrollCount + clickCount + moveCount
        let totalInput = totalMouse + keystrokeCount

        guard totalInput > 0 else { return 0.5 } // no input = neutral

        let keyboardRatio = Double(keystrokeCount) / Double(totalInput)

        // Heavy scrolling with no typing = reading/browsing = low flow
        if scrollCount > 20 && keystrokeCount < 5 {
            return 0.15
        }

        // Mouse-only with no keyboard = browsing
        if keystrokeCount == 0 && totalMouse > 10 {
            return 0.1
        }

        // High keyboard ratio = deep work
        return min(1.0, keyboardRatio * 1.2)
    }
}
