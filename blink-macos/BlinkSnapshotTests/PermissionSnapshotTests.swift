import XCTest
import SwiftUI
@testable import Blink

/// Snapshots for the post-refactor permission UI. The old
/// PermissionOnboardingView + PermissionGuideView tests were deleted —
/// those views no longer exist (the wizard + guide were merged into
/// MicrophonePermissionPage / InputMonitoringPermissionPage which now
/// serve both onboarding and recovery paths).
final class MicrophonePermissionPageSnapshotTests: SnapshotTestCase {
    @MainActor func testMicrophonePage() {
        let themes: [(String, BlinkTheme)] = [
            ("peach", .peach), ("midnight", .midnight), ("sage", .sage),
            ("sand", .sand), ("mono", .mono),
        ]
        for (name, theme) in themes {
            for cs in [ColorScheme.light, .dark] {
                let label = "\(name)_\(cs == .dark ? "dark" : "light")"
                assertSnapshot(
                    of: MicrophonePermissionPage(theme: theme, onBack: {}, onAdvance: {}),
                    named: "mic_permission_\(label)",
                    width: 900, height: 650,
                    colorScheme: cs
                )
            }
        }
    }
}

final class InputMonitoringPermissionPageSnapshotTests: SnapshotTestCase {
    @MainActor func testStandardMode() {
        let themes: [(String, BlinkTheme)] = [
            ("peach", .peach), ("midnight", .midnight), ("sage", .sage),
            ("sand", .sand), ("mono", .mono),
        ]
        for (name, theme) in themes {
            for cs in [ColorScheme.light, .dark] {
                let label = "\(name)_\(cs == .dark ? "dark" : "light")"
                assertSnapshot(
                    of: InputMonitoringPermissionPage(
                        theme: theme,
                        mode: .standard,
                        onBack: {},
                        onComplete: { _ in }
                    ),
                    named: "im_permission_standard_\(label)",
                    width: 900, height: 650,
                    colorScheme: cs
                )
            }
        }
    }

    @MainActor func testStaleGrantMode() {
        let themes: [(String, BlinkTheme)] = [
            ("peach", .peach), ("midnight", .midnight), ("sage", .sage),
            ("sand", .sand), ("mono", .mono),
        ]
        for (name, theme) in themes {
            for cs in [ColorScheme.light, .dark] {
                let label = "\(name)_\(cs == .dark ? "dark" : "light")"
                assertSnapshot(
                    of: InputMonitoringPermissionPage(
                        theme: theme,
                        mode: .staleGrant,
                        onBack: nil,
                        onComplete: { _ in }
                    ),
                    named: "im_permission_stale_\(label)",
                    width: 700, height: 540,
                    colorScheme: cs
                )
            }
        }
    }
}
