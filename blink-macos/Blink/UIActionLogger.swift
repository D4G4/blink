import Foundation

/// Centralized UI action logging — tracks user taps, window opens/closes, navigation.
enum UIActionLogger {
    static func windowOpened(_ name: String) {
        Log.i("Window opened: \(name)")
    }

    static func windowClosed(_ name: String) {
        Log.i("Window closed: \(name)")
    }

    static func buttonTapped(_ name: String, context: String = "") {
        if context.isEmpty {
            Log.i("Button tapped: \(name)")
        } else {
            Log.i("Button tapped: \(name) [\(context)]")
        }
    }

    static func tabSelected(_ name: String) {
        Log.i("Tab selected: \(name)")
    }

    static func settingChanged(_ name: String, value: String) {
        Log.i("Setting changed: \(name) = \(value)")
    }

    static func onboardingStep(_ step: String) {
        Log.i("Onboarding: \(step)")
    }
}
