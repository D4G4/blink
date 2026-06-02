import XCTest
import SwiftUI
@testable import Blink

/// Snapshot coverage for the post-onboarding / setup-flow surfaces that had
/// none: the detection-mode choice page, the onboarding theme picker, the flow
/// sensitivity page, and the Input Monitoring rationale sheet.
///
/// Matrix: peach + midnight × light + dark — covers both colorScheme branches
/// and a warm/light-first theme plus a dark theme. (The older page tests sweep
/// all five themes; these new suites use two representative themes to keep the
/// golden count and push size manageable.)
final class SetupFlowSnapshotTests: SnapshotTestCase {
    private let themes: [(String, BlinkTheme)] = [("peach", .peach), ("midnight", .midnight)]
    private let schemes: [(String, ColorScheme)] = [("light", .light), ("dark", .dark)]

    @MainActor func testDetectionModeChoicePage() {
        for (tn, theme) in themes {
            for (sn, cs) in schemes {
                assertSnapshot(
                    of: DetectionModeChoicePage(theme: theme, onPickSmart: {}, onPickSimple: {}),
                    named: "detection_choice_\(tn)_\(sn)",
                    width: 900, height: 650, colorScheme: cs
                )
            }
        }
    }

    @MainActor func testFlowSensitivityPage() {
        for (tn, theme) in themes {
            for (sn, cs) in schemes {
                assertSnapshot(
                    of: FlowSensitivityPage(
                        theme: theme,
                        sensitivity: .constant(0.5),
                        onBack: {}, onLearnMore: {}, onGetStarted: {}
                    ),
                    named: "flow_sensitivity_page_\(tn)_\(sn)",
                    width: 900, height: 650, colorScheme: cs
                )
            }
        }
    }

    @MainActor func testOnboardingThemePicker() {
        for (tn, theme) in themes {
            for (sn, cs) in schemes {
                assertSnapshot(
                    of: OnboardingView(themeManager: ThemeManager.preview(theme), onComplete: {}),
                    named: "onboarding_picker_\(tn)_\(sn)",
                    width: 900, height: 650, colorScheme: cs
                )
            }
        }
    }

    @MainActor func testInputMonitoringRationale() {
        for (tn, theme) in themes {
            for (sn, cs) in schemes {
                assertSnapshot(
                    of: InputMonitoringRationaleView(theme: theme, onDismiss: {}),
                    named: "im_rationale_\(tn)_\(sn)",
                    width: 620, height: 560, colorScheme: cs
                )
            }
        }
    }
}
