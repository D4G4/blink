import SwiftUI

/// Hosts the microphone + input-monitoring permission steps as a flow
/// that can be presented OUTSIDE of onboarding. Used when:
///   - First launch after onboarding (theme + flow already chosen)
///   - App restart mid-permission-setup (TCC grant restarted Blink before
///     the user finished the IM step — see AppState comments)
///   - User cleared basicMode opt-in and wants to enable smart mode
///
/// Auto-advances through any already-resolved step
/// (MicrophonePermissionPage / InputMonitoringPermissionPage each call
/// onAdvance/onComplete on appear if their permission is already
/// granted), so a partially-completed setup picks up where it left off.
struct PermissionFlowView: View {
    let theme: BlinkTheme
    /// `basicMode` is true when the user explicitly opted out of Input
    /// Monitoring (basic-timer-only path).
    let onComplete: (_ basicMode: Bool) -> Void

    @State private var currentStep: Step = .microphone

    enum Step { case microphone, inputMonitoring }

    var body: some View {
        ZStack {
            if currentStep == .microphone {
                MicrophonePermissionPage(
                    theme: theme,
                    // No back from the permission flow — there's nothing
                    // before it. (Onboarding is already done.)
                    onBack: nil,
                    onAdvance: {
                        withAnimation(.easeInOut(duration: 0.4)) {
                            currentStep = .inputMonitoring
                        }
                    }
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .leading).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
            } else {
                InputMonitoringPermissionPage(
                    theme: theme,
                    mode: .standard,
                    onBack: {
                        withAnimation(.easeInOut(duration: 0.4)) {
                            currentStep = .microphone
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
