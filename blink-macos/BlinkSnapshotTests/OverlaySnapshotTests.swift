import XCTest
import SwiftUI
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
