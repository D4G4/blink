import Foundation
import CoreGraphics
import BlinkCore

/// Monitors keyboard and mouse events via CGEventTap (listen-only).
/// Requires Input Monitoring permission.
final class MacInputMonitor: InputEventSource {
    var onKeystroke: ((KeystrokeEvent) -> Void)?
    var onMouseEvent: ((MouseEvent) -> Void)?

    /// Exposed for tap liveness check via `CGEvent.tapIsEnabled(tap:)`.
    private(set) var eventTap: CFMachPort?
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
            BlinkLog.permission.error("CGEventTap creation failed in MacInputMonitor — input monitoring will NOT work this session")
            return
        }

        self.eventTap = tap

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        self.runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        BlinkLog.permission.info("CGEventTap created and enabled in MacInputMonitor — input monitoring active")
    }

    private var tapDeathLogged = false

    /// Re-enable the event tap if macOS disabled it.
    /// Logs only once to avoid spamming the log buffer.
    func reEnableTapIfNeeded() {
        guard let tap = eventTap else { return }
        if CGEvent.tapIsEnabled(tap: tap) {
            tapDeathLogged = false  // tap is alive, reset
            return
        }
        CGEvent.tapEnable(tap: tap, enable: true)
        if !tapDeathLogged {
            tapDeathLogged = true
            BlinkLog.permission.info("CGEventTap was disabled — attempted re-enable")
        }
    }

    /// Whether the tap is alive and receiving events.
    var isTapAlive: Bool {
        guard let tap = eventTap else { return false }
        return CGEvent.tapIsEnabled(tap: tap)
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
        // macOS sends these when it kills the tap — log the actual reason
        if type == .tapDisabledByTimeout {
            BlinkLog.permission.info("CGEventTap KILLED: tapDisabledByTimeout — callback was too slow")
            if let userInfo {
                let monitor = Unmanaged<MacInputMonitor>.fromOpaque(userInfo).takeUnretainedValue()
                if let tap = monitor.eventTap {
                    CGEvent.tapEnable(tap: tap, enable: true)
                }
            }
            return Unmanaged.passUnretained(event)
        }
        if type == .tapDisabledByUserInput {
            BlinkLog.permission.info("CGEventTap KILLED: tapDisabledByUserInput — secure input active")
            return Unmanaged.passUnretained(event)
        }

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
