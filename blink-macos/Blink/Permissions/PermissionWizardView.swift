import SwiftUI
import AVFoundation

/// Two-step permission wizard shown immediately after onboarding completes.
/// Replaces the separate PermissionGuideView and MicrophonePermissionView
/// with a single window that holds state across both steps — so the user
/// sees clear progress (step 1 → checkmark → step 2) and the window
/// doesn't flash close/open between them.
///
/// Step order is Microphone FIRST, then Input Monitoring. Reason: IM grant
/// can cause macOS to restart the app (TCC-tied permission re-eval). If we
/// asked IM first, the restart would wipe wizard state mid-flow. Doing the
/// simpler mic step first ensures it survives any IM-triggered restart.
struct PermissionWizardView: View {
    let theme: BlinkTheme

    /// Called when BOTH steps are resolved (granted, skipped, or opted into
    /// basic mode), so the caller can dismiss the window and start the
    /// engine. `basicMode` is true when the user explicitly chose to run
    /// without Input Monitoring (dumb timer only — no flow detection).
    let onAllDone: (_ basicMode: Bool) -> Void

    @Environment(\.colorScheme) private var colorScheme

    enum Step { case microphone, inputMonitoring }

    @State private var currentStep: Step = .microphone
    @State private var micDone: Bool = false
    @State private var imDone: Bool = false
    @State private var imRetryAttempts: Int = 0

    /// Periodic CGPreflightListenEventAccess check — flips imDone when the
    /// user grants Input Monitoring via System Settings.
    @State private var imPollTimer: Timer?

    var body: some View {
        let fg = theme.onBackgroundText(for: colorScheme)
        let bgTop = theme.backgroundTop(for: colorScheme)

        ZStack {
            theme.backgroundGradient(for: colorScheme)
                .ignoresSafeArea()

            RadialGradient(
                colors: [fg.opacity(0.1), .clear],
                center: .top,
                startRadius: 50,
                endRadius: 400
            )

            VStack(spacing: 0) {
                stepIndicator(fg: fg, bgTop: bgTop)
                    .padding(.top, 22)
                    .padding(.bottom, 18)

                Group {
                    if currentStep == .microphone {
                        microphoneStep(fg: fg, bgTop: bgTop)
                    } else {
                        inputMonitoringStep(fg: fg, bgTop: bgTop)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
                .animation(.easeInOut(duration: 0.35), value: currentStep)
            }
        }
        .frame(minWidth: 700, minHeight: 500)
        .onDisappear { stopIMPolling() }
    }

    // MARK: - Step indicator

    private func stepIndicator(fg: Color, bgTop: Color) -> some View {
        HStack(spacing: 0) {
            stepCircle(num: 1, label: "Microphone", isDone: micDone, isCurrent: currentStep == .microphone, fg: fg, bgTop: bgTop)
            Rectangle()
                .fill(micDone ? fg : fg.opacity(0.3))
                .frame(width: 70, height: 2)
                .padding(.horizontal, 6)
                .padding(.bottom, 18)
            stepCircle(num: 2, label: "Input Monitoring", isDone: imDone, isCurrent: currentStep == .inputMonitoring, fg: fg, bgTop: bgTop)
        }
    }

    private func stepCircle(num: Int, label: String, isDone: Bool, isCurrent: Bool, fg: Color, bgTop: Color) -> some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(isDone || isCurrent ? fg : fg.opacity(0.25))
                    .frame(width: 32, height: 32)
                if isDone {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(bgTop)
                } else {
                    Text("\(num)")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(isCurrent ? bgTop : fg)
                }
            }
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(fg.opacity(isCurrent || isDone ? 1.0 : 0.6))
        }
    }

    // MARK: - Step 1: Microphone

    private func microphoneStep(fg: Color, bgTop: Color) -> some View {
        VStack(spacing: 0) {
            VStack(spacing: 4) {
                Image(systemName: "mic.fill")
                    .font(.system(size: 28, weight: .light))
                    .foregroundStyle(fg)
                    .padding(.bottom, 6)
                Text("Microphone Access")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(fg)
                Text("So breaks don't interrupt your calls")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(fg.opacity(0.85))
            }
            .padding(.bottom, 22)

            VStack(alignment: .leading, spacing: 12) {
                rationaleRow(
                    icon: "checkmark.circle.fill",
                    title: "What it's for",
                    body: "Detect when an app is using your mic so the break timer auto-pauses during meetings and calls.",
                    fg: fg
                )
                rationaleRow(
                    icon: "eye.slash.fill",
                    title: "What we don't do",
                    body: "We only check whether the mic is in use — we never record, transmit, or store any audio.",
                    fg: fg
                )
                rationaleRow(
                    icon: "hand.raised.fill",
                    title: "If you skip",
                    body: "Everything else still works. The timer just won't auto-pause during calls — you can manually pause from the menu bar.",
                    fg: fg
                )
            }
            .frame(maxWidth: 520)
            .padding(.horizontal, 40)

            Spacer()

            HStack(spacing: 12) {
                wizardButton(label: "Skip", icon: nil, primary: false, fg: fg, bgTop: bgTop) {
                    BlinkLog.permission.info("User skipped microphone step")
                    micDone = true
                    advanceToInputMonitoring()
                }
                wizardButton(label: "Grant Access", icon: "mic.fill", primary: true, fg: fg, bgTop: bgTop) {
                    Task { @MainActor in
                        let granted = await PermissionManager.requestMicrophoneAccess()
                        BlinkLog.permission.info("Microphone step resolved: granted=\(granted)")
                        micDone = true
                        advanceToInputMonitoring()
                    }
                }
            }
            .padding(.bottom, 28)
        }
    }

    private func advanceToInputMonitoring() {
        // If IM is already granted from a previous launch, skip step 2 entirely.
        if PermissionManager.isPermissionGranted() {
            BlinkLog.permission.info("IM already granted — skipping step 2")
            imDone = true
            onAllDone(false)
            return
        }
        withAnimation { currentStep = .inputMonitoring }
        // Start polling so we auto-detect the grant when it happens, but do
        // NOT auto-fire the OS dialog here — that only happens when the
        // user taps "Open Settings" (so the system prompt and the Settings
        // pane appear together as a single explicit user-initiated action).
        startIMPolling()
    }

    // MARK: - Step 2: Input Monitoring

    private func inputMonitoringStep(fg: Color, bgTop: Color) -> some View {
        VStack(spacing: 0) {
            VStack(spacing: 4) {
                Image(systemName: "keyboard")
                    .font(.system(size: 28, weight: .light))
                    .foregroundStyle(fg)
                    .padding(.bottom, 6)
                Text("Grant Input Monitoring")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(fg)
                Text("So Blink can detect your typing rhythm + flow state")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(fg.opacity(0.85))
            }
            .padding(.bottom, 18)

            HStack(spacing: 24) {
                Image("InputMonitoringSettings")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 280)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(fg.opacity(0.25), lineWidth: 1))
                    .shadow(color: .black.opacity(0.35), radius: 18, y: 8)

                VStack(alignment: .leading, spacing: 0) {
                    imStepRow(num: 1, title: "Click +  button", fg: fg, bgTop: bgTop)
                    imStepConnector(fg: fg)
                    imStepRow(num: 2, title: "Find Blink → Open", fg: fg, bgTop: bgTop)
                    imStepConnector(fg: fg)
                    imStepRow(num: 3, title: "Toggle on", fg: fg, bgTop: bgTop)
                }
                .padding(14)
                .background(fg.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .frame(width: 200)
            }
            .padding(.horizontal, 28)

            Spacer()

            HStack(spacing: 12) {
                wizardButton(label: "Open Settings", icon: "gear", primary: true, fg: fg, bgTop: bgTop) {
                    // User-initiated: fire the OS prompt and open the
                    // Settings pane together. On first invocation the OS
                    // dialog appears (with "Open System Settings" button
                    // that lands on the same pane); on subsequent
                    // invocations the request is a no-op and the deeplink
                    // is the working path.
                    NSApp.activate(ignoringOtherApps: true)
                    PermissionManager.requestInputMonitoringAccess()
                    PermissionManager.openInputMonitoringSettings()
                }
                wizardButton(label: "I've granted access", icon: "checkmark.circle.fill", primary: false, fg: fg, bgTop: bgTop) {
                    checkIMGrant()
                }
            }
            .padding(.bottom, 8)

            // Basic-mode opt-out — subtle so it's the deliberate "I don't
            // want the smart features" path, not the obvious default.
            Button {
                BlinkLog.permission.info("User chose basic mode (no Input Monitoring) — engine will run with simple timer only")
                stopIMPolling()
                imDone = true
                onAllDone(true)
            } label: {
                Text("Continue with basic timer (no smart timing)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(fg.opacity(0.65))
                    .underline()
            }
            .buttonStyle(.plain)
            .padding(.bottom, 22)
        }
    }

    private func imStepRow(num: Int, title: String, fg: Color, bgTop: Color) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(fg).frame(width: 22, height: 22)
                Text("\(num)").font(.system(size: 12, weight: .bold)).foregroundStyle(bgTop)
            }
            Text(title).font(.system(size: 13, weight: .bold)).foregroundStyle(fg)
        }
        .padding(.vertical, 6)
    }

    private func imStepConnector(fg: Color) -> some View {
        Rectangle().fill(fg.opacity(0.3)).frame(width: 2, height: 8).padding(.leading, 10)
    }

    // MARK: - IM grant polling + manual check

    private func startIMPolling() {
        imPollTimer?.invalidate()
        imPollTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            DispatchQueue.main.async {
                if PermissionManager.isPermissionGranted() {
                    BlinkLog.permission.info("IM grant detected by poll — wizard complete")
                    stopIMPolling()
                    imDone = true
                    onAllDone(false)
                }
            }
        }
    }

    private func stopIMPolling() {
        imPollTimer?.invalidate()
        imPollTimer = nil
    }

    private func checkIMGrant() {
        BlinkLog.permission.info("User tapped 'I've granted access' (attempt \(imRetryAttempts + 1))")
        if PermissionManager.isPermissionGranted() {
            stopIMPolling()
            imDone = true
            onAllDone(false)
            return
        }
        imRetryAttempts += 1
        // Brief retry delay — TCC grant can take a moment to propagate
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if PermissionManager.isPermissionGranted() {
                stopIMPolling()
                imDone = true
                onAllDone(false)
            }
        }
    }

    // MARK: - Reusable button

    private func wizardButton(label: String, icon: String?, primary: Bool, fg: Color, bgTop: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon {
                    Image(systemName: icon).font(.system(size: 12, weight: .semibold))
                }
                Text(label).font(.system(size: 14, weight: .bold))
            }
            .foregroundStyle(primary ? bgTop : fg)
            .frame(height: 40)
            .padding(.horizontal, 22)
            .background(primary ? fg : fg.opacity(0.22))
            .clipShape(Capsule())
            .shadow(color: primary ? .black.opacity(0.2) : .clear, radius: primary ? 10 : 0, y: primary ? 5 : 0)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Reusable rationale row

    private func rationaleRow(icon: String, title: String, body: String, fg: Color) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(fg)
                .frame(width: 22, height: 22)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 13, weight: .bold)).foregroundStyle(fg)
                Text(body).font(.system(size: 12)).foregroundStyle(fg.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }
}

#Preview("Wizard — Peach (mic step)") {
    PermissionWizardView(theme: .peach, onAllDone: {})
        .frame(width: 700, height: 500)
}

#Preview("Wizard — Midnight (mic step)") {
    PermissionWizardView(theme: .midnight, onAllDone: {})
        .frame(width: 700, height: 500)
        .preferredColorScheme(.dark)
}
