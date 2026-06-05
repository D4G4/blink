import XCTest
import SwiftUI
import BlinkCore
@testable import Blink

final class BreakTimerSnapshotTests: SnapshotTestCase {
    @MainActor func testBreakTimer() {
        for v in allThemeVariants {
            assertSnapshot(
                of: BreakPhaseView(theme: v.theme, model: BreakPhaseModel(), onComplete: {}, onSkip: {}),
                named: "break_timer_\(v.snapshotName)",
                width: 500, height: 420,
                colorScheme: v.colorScheme
            )
        }
    }

    /// Render every non-default suggestion variant so the icon+subtitle
    /// layout is captured (the default `.lookFarAway` keeps the minimal
    /// title-only design and is already covered by `testBreakTimer`).
    /// We pick one light + one dark theme rather than the full 12-variant
    /// matrix — the cross-theme rendering is already verified above; here
    /// we're verifying the per-suggestion content (icon glyph, copy).
    @MainActor func testBreakTimerSuggestions() {
        let suggestions: [BreakSuggestion] = [
            .breathe, .drinkWater, .getUp, .takeAWalk, .touchGrass
        ]
        let variants: [ThemeVariant] = [
            ThemeVariant(name: "peach", theme: .peach, colorScheme: .light),
            ThemeVariant(name: "midnight", theme: .midnight, colorScheme: .dark),
        ]
        for v in variants {
            for s in suggestions {
                // Variant breaks get 25s (vs 20 for the default) so the
                // user has time to read the subtitle. Mirror that here so
                // the snapshot reflects the duration the live overlay
                // would actually show.
                assertSnapshot(
                    of: BreakPhaseView(
                        theme: v.theme,
                        model: BreakPhaseModel(duration: 25),
                        suggestion: s,
                        onComplete: {}, onSkip: {}
                    ),
                    named: "break_timer_\(s.rawValue)_\(v.snapshotName)",
                    width: 500, height: 420,
                    colorScheme: v.colorScheme
                )
            }
        }
    }
}

final class CountdownSnapshotTests: SnapshotTestCase {
    @MainActor func testCountdown() {
        for v in allThemeVariants {
            assertSnapshot(
                of: CountdownPhaseView(theme: v.theme, onCountdownDone: {}, onSkip: {}),
                named: "countdown_\(v.snapshotName)",
                width: 400, height: 280,
                colorScheme: v.colorScheme
            )
        }
    }
}

final class ToastSnapshotTests: SnapshotTestCase {
    @MainActor func testToast() {
        for v in allThemeVariants {
            assertSnapshot(
                of: ToastView(theme: v.theme, onDone: {}),
                named: "toast_\(v.snapshotName)",
                width: 280, height: 72,
                colorScheme: v.colorScheme
            )
        }
    }

    @MainActor func testTimerExtendedToast() {
        for v in allThemeVariants {
            assertSnapshot(
                of: TimerExtendedToastView(theme: v.theme, onDismiss: {}, onTakeBreak: {}),
                named: "timer_extended_\(v.snapshotName)",
                width: 280, height: 100,
                colorScheme: v.colorScheme
            )
        }
    }

    @MainActor func testFlowNudgeToast() {
        for v in allThemeVariants {
            assertSnapshot(
                of: FlowNudgeToastView(theme: v.theme, message: "Focused — extended 10 min", onDismiss: {}, onTakeBreak: {}),
                named: "flow_nudge_\(v.snapshotName)",
                width: 320, height: 80,
                colorScheme: v.colorScheme
            )
        }
    }
}
