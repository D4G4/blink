import Foundation

public struct KeystrokeEvent: Sendable {
    public let timestamp: TimeInterval

    public init(timestamp: TimeInterval) {
        self.timestamp = timestamp
    }
}

public struct MouseEvent: Sendable {
    public let timestamp: TimeInterval
    public let kind: MouseEventKind

    public init(timestamp: TimeInterval, kind: MouseEventKind) {
        self.timestamp = timestamp
        self.kind = kind
    }
}

public enum MouseEventKind: Sendable {
    case move(deltaX: Double, deltaY: Double)
    case scroll(deltaY: Double)
    case click
}

public protocol InputEventSource: AnyObject {
    var onKeystroke: ((KeystrokeEvent) -> Void)? { get set }
    var onMouseEvent: ((MouseEvent) -> Void)? { get set }
    func startMonitoring()
    func stopMonitoring()
}
