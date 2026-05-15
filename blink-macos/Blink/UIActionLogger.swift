import os

/// Centralized UI action logging — tracks user taps, window opens/closes, navigation.
/// View in Console.app with subsystem filter: com.blink20.app, category: UI
enum UIActionLogger {
    private static let log = Logger(subsystem: "com.blink20.app", category: "UI")

    static func windowOpened(_ name: String) {
        log.info("Window opened: \(name)")
    }

    static func windowClosed(_ name: String) {
        log.info("Window closed: \(name)")
    }

    static func buttonTapped(_ name: String, context: String = "") {
        if context.isEmpty {
            log.info("Button tapped: \(name)")
        } else {
            log.info("Button tapped: \(name) [\(context)]")
        }
    }

    static func tabSelected(_ name: String) {
        log.info("Tab selected: \(name)")
    }

    static func settingChanged(_ name: String, value: String) {
        log.info("Setting changed: \(name) = \(value)")
    }

    static func onboardingStep(_ step: String) {
        log.info("Onboarding: \(step)")
    }
}
