import Foundation
import CoreGraphics
import BlinkCore

/// Monitors keyboard and mouse events via CGEventTap (listen-only).
/// Requires Accessibility permission.
final class MacInputMonitor: InputEventSource {
    var onKeystroke: ((KeystrokeEvent) -> Void)?
    var onMouseEvent: ((MouseEvent) -> Void)?

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    func startMonitoring() {
        let eventMask: CGEventMask = (
            (1 << CGEventType.keyDown.rawValue) |
            (1 << CGEventType.mouseMoved.rawValue) |
            (1 << CGEventType.scrollWheel.rawValue) |
            (1 << CGEventType.leftMouseDown.rawValue) |
            (1 << CGEventType.rightMouseDown.rawValue)
        )

        // Store self in a pointer for the C callback
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .tailAppendEventTap,
            options: .listenOnly,
            eventsOfInterest: eventMask,
            callback: MacInputMonitor.eventCallback,
            userInfo: selfPtr
        ) else {
            print("[Blink] Failed to create CGEventTap — Accessibility permission may not be granted")
            return
        }

        self.eventTap = tap

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        self.runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    func stopMonitoring() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
    }

    // C-compatible callback
    private static let eventCallback: CGEventTapCallBack = { _, type, event, userInfo in
        guard let userInfo else { return Unmanaged.passUnretained(event) }
        let monitor = Unmanaged<MacInputMonitor>.fromOpaque(userInfo).takeUnretainedValue()
        let timestamp = Date().timeIntervalSinceReferenceDate

        switch type {
        case .keyDown:
            // Only capture timing — never the keycode or character
            monitor.onKeystroke?(KeystrokeEvent(timestamp: timestamp))

        case .mouseMoved:
            let dx = event.getDoubleValueField(.mouseEventDeltaX)
            let dy = event.getDoubleValueField(.mouseEventDeltaY)
            monitor.onMouseEvent?(MouseEvent(timestamp: timestamp, kind: .move(deltaX: dx, deltaY: dy)))

        case .scrollWheel:
            let dy = event.getDoubleValueField(.scrollWheelEventDeltaAxis1)
            monitor.onMouseEvent?(MouseEvent(timestamp: timestamp, kind: .scroll(deltaY: dy)))

        case .leftMouseDown, .rightMouseDown:
            monitor.onMouseEvent?(MouseEvent(timestamp: timestamp, kind: .click))

        default:
            break
        }

        return Unmanaged.passUnretained(event)
    }

    deinit {
        stopMonitoring()
    }
}
