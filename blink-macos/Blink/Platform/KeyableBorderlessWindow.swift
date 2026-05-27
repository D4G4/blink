import AppKit

/// Borderless `NSWindow`s default to `canBecomeKey == false`, which means
/// `makeKeyAndOrderFront(_:)` silently fails to focus them and macOS logs
/// "called on ... which returned NO from -[NSWindow canBecomeKeyWindow]".
/// In Blink we use borderless windows for onboarding, the permission guide,
/// and similar modal-like surfaces, so we want them to be focusable.
final class KeyableBorderlessWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}
