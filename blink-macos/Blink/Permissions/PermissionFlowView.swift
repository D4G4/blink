import SwiftUI

/// Hosts the detection-mode choice + permission steps (mic, input
/// monitoring) that follow onboarding. Presented OUTSIDE of onboarding
/// when:
///   - First launch after onboarding (theme + flow already chosen)
///   - App restart mid-permission-setup (TCC grant restarted Blink before
///     the user finished the IM step — see AppState comments)
///   - User cleared basicMode opt-in and wants to enable smart mode
///
/// Step machine: `.detectionMode` → `.microphone` → `.inputMonitoring`.
/// From `.microphone` or `.inputMonitoring`, the user can navigate BACK
/// to `.detectionMode` at any time (so they can switch to Simple after
/// seeing what Smart requires). Picking Simple on the choice page
/// completes the flow immediately with no permissions requested.
///
/// MicrophonePermissionPage / InputMonitoringPermissionPage each call
/// onAdvance/onComplete on appear if their permission is already
/// granted, so a partially-completed setup picks up where it left off.
struct PermissionFlowView: View {
    let theme: BlinkTheme
    /// `basicMode` is true when the user explicitly opted into Simple
    /// timer mode (no Input Monitoring requested).
    let onComplete: (_ basicMode: Bool) -> Void

    @State private var currentStep: Step = .detectionMode

    enum Step { case detectionMode, microphone, inputMonitoring }

    var body: some View {
        ZStack {
            switch currentStep {
            case .detectionMode:
                DetectionModeChoicePage(
                    theme: theme,
                    onPickSmart: {
                        withAnimation(.easeInOut(duration: 0.4)) {
                            currentStep = .microphone
                        }
                    },
                    onPickSimple: {
                        // Skip mic + IM entirely. AppState's basicMode
                        // branch persists the opt-in and starts the
                        // simple-timer runtime.
                        onComplete(true)
                    }
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .leading).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))

            case .microphone:
                MicrophonePermissionPage(
                    theme: theme,
                    onBack: {
                        withAnimation(.easeInOut(duration: 0.4)) {
                            currentStep = .detectionMode
                        }
                    },
                    onAdvance: {
                        withAnimation(.easeInOut(duration: 0.4)) {
                            currentStep = .inputMonitoring
                        }
                    }
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .trailing).combined(with: .opacity)
                ))

            case .inputMonitoring:
                InputMonitoringPermissionPage(
                    theme: theme,
                    mode: .standard,
                    onBack: {
                        withAnimation(.easeInOut(duration: 0.4)) {
                            currentStep = .detectionMode
                        }
                    },
                    onComplete: { basicMode in
                        onComplete(basicMode)
                    }
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .trailing).combined(with: .opacity)
                ))
            }
        }
    }
}

#Preview("Peach") {
    PermissionFlowView(theme: .peach, onComplete: { _ in })
        .frame(width: 900, height: 650)
}
