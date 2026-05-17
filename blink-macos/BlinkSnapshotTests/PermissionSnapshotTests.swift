import XCTest
import SwiftUI
@testable import Blink

final class PermissionOnboardingSnapshotTests: SnapshotTestCase {
    @MainActor func testPermissionOnboarding() {
        let themes: [(String, BlinkTheme)] = [
            ("peach", .peach), ("midnight", .midnight), ("sage", .sage),
            ("sand", .sand), ("mono", .mono),
        ]
        for (name, theme) in themes {
            for cs in [ColorScheme.light, .dark] {
                let label = "\(name)_\(cs == .dark ? "dark" : "light")"
                assertSnapshot(
                    of: PermissionOnboardingView(theme: theme, onContinue: {}),
                    named: "permission_onboarding_\(label)",
                    width: 500, height: 450,
                    colorScheme: cs
                )
            }
        }
    }
}

final class PermissionGuideSnapshotTests: SnapshotTestCase {
    @MainActor func testPermissionGuide() {
        let themes: [(String, BlinkTheme)] = [
            ("peach", .peach), ("midnight", .midnight), ("sage", .sage),
            ("sand", .sand), ("mono", .mono),
        ]
        for (name, theme) in themes {
            for cs in [ColorScheme.light, .dark] {
                let label = "\(name)_\(cs == .dark ? "dark" : "light")"
                assertSnapshot(
                    of: PermissionGuideView(theme: theme, onOpenSettings: {}, onConfirmGranted: {}),
                    named: "permission_guide_\(label)",
                    width: 700, height: 420,
                    colorScheme: cs
                )
            }
        }
    }
}
