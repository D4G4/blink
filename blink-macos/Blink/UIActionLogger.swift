import Foundation

/// Centralized UI action logging — tracks user taps, window opens/closes, navigation.
enum UIActionLogger {
    static func windowOpened(_ name: String) {
        BlinkLog.ui.info("Window opened: \(name)")
    }

    static func windowClosed(_ name: String) {
        BlinkLog.ui.info("Window closed: \(name)")
    }

    static func buttonTapped(_ name: String, context: String = "") {
        if context.isEmpty {
            BlinkLog.ui.info("Button tapped: \(name)")
        } else {
            BlinkLog.ui.info("Button tapped: \(name) [\(context)]")
        }
    }

    static func tabSelected(_ name: String) {
        BlinkLog.ui.info("Tab selected: \(name)")
    }

    static func settingChanged(_ name: String, value: String) {
        BlinkLog.ui.info("Setting changed: \(name) = \(value)")
    }

    static func onboardingStep(_ step: String) {
        BlinkLog.ui.info("Onboarding: \(step)")
    }
}
