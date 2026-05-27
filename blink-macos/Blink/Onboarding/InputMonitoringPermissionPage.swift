import SwiftUI

/// Onboarding page 4: input monitoring permission step.
///
/// Replaces the standalone PermissionWizardView's IM step — inlined here
/// so the whole permission flow lives in the same onboarding window.
///
/// Buttons:
///   - Open Settings   → fires `CGRequestListenEventAccess` AND opens the
///                       Privacy → Input Monitoring pane. On first call,
///                       the OS dialog appears; subsequent calls just
///                       deeplink to the pane (no-op).
///   - I've granted    → manual re-check (in case the user thinks they've
///                       granted but the TCC cache hasn't propagated).
///   - Continue with basic timer (subtle link) → opt out, run with simple
///                       wall-clock timer only. Sets basicModeOptIn=true.
///
/// Polling: `CGPreflightListenEventAccess` is checked every 2s so the
/// page auto-completes when the grant takes effect, without making the
/// user come back and click "I've granted access."
struct InputMonitoringPermissionPage: View {
    /// `standard` is the onboarding flow ("Grant Input Monitoring").
    /// `staleGrant` is the post-onboarding recovery ("Permission Granted
    /// — But Not Working") that fires when CGPreflightListenEventAccess
    /// is true but CGEvent.tapCreate fails — typically a binary CDHash
    /// change after a Blink update, where TCC still holds a grant for
    /// the previous binary. Hides the basic-mode opt-out (the user
    /// already chose smart mode; recovery isn't the moment to ask them
    /// to downgrade).
    enum Mode { case standard, staleGrant }

    let theme: BlinkTheme
    var mode: Mode = .standard
    /// nil when there's no "back" target (recovery window has no
    /// preceding page; onboarding always has Microphone behind it).
    let onBack: (() -> Void)?
    /// Called when this step resolves. `basicMode` is true when the user
    /// explicitly opted out of Input Monitoring (basic-timer-only path).
    /// Always false in `.staleGrant` mode (no opt-out shown).
    let onComplete: (_ basicMode: Bool) -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var pollTimer: Timer?
    @State private var showWhySheet: Bool = false
    @State private var retryAttempts: Int = 0

    var body: some View {
        GeometryReader { proxy in
            content(availableHeight: proxy.size.height)
        }
        .onAppear {
            initializeFromCurrentStatus()
            startPolling()
        }
        .onDisappear { stopPolling() }
        .sheet(isPresented: $showWhySheet) {
            InputMonitoringRationaleView(theme: theme) { showWhySheet = false }
                .frame(width: 540, height: 520)
        }
    }

    @ViewBuilder
    private func content(availableHeight: CGFloat) -> some View {
        let isCompact = availableHeight < 700
        let iconSize: CGFloat = isCompact ? 38 : 48
        let titleSize: CGFloat = isCompact ? 24 : 28
        let outerVPad: CGFloat = isCompact ? 20 : 40

        let fg = theme.onBackgroundText(for: colorScheme)
        let bgTop = theme.backgroundTop(for: colorScheme)

        let iconName = mode == .staleGrant ? "exclamationmark.triangle.fill" : "keyboard"
        let title = mode == .staleGrant ? "Permission Granted — But Not Working" : "Grant Input Monitoring"
        let subtitle = mode == .staleGrant
            ? "macOS ties permissions to the exact app binary — toggle Blink off and back on so the new version inherits it."
            : "So Blink can detect your typing rhythm and flow state"

        return ZStack(alignment: .topLeading) {
            theme.backgroundGradient(for: colorScheme).ignoresSafeArea()

            if onBack != nil {
                backButton(fg: fg)
            }

            VStack(spacing: 0) {
                Image(systemName: iconName)
                    .font(.system(size: iconSize, weight: .light))
                    .foregroundStyle(fg)
                    .padding(.bottom, 10)

                Text(title)
                    .font(.system(size: titleSize, weight: .bold, design: .rounded))
                    .foregroundStyle(fg)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                Text(subtitle)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(fg.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.top, 4)

                // "Why does Blink need this?" only makes sense for the
                // first-grant flow — in stale-grant recovery the user
                // already knows why.
                if mode == .standard {
                    Button {
                        showWhySheet = true
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "questionmark.circle").font(.system(size: 12))
                            Text("Why does Blink need this?").font(.system(size: 12, weight: .medium))
                        }
                        .foregroundStyle(fg)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(fg.opacity(0.15))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 10)
                }

                Spacer(minLength: 18)

                HStack(spacing: 28) {
                    Image("InputMonitoringSettings")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: 320)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(fg.opacity(0.25), lineWidth: 1))
                        .shadow(color: .black.opacity(0.35), radius: 18, y: 8)

                    VStack(alignment: .leading, spacing: 0) {
                        imStepRow(num: 1, title: "Click +  button", fg: fg, bgTop: bgTop)
                        imStepConnector(fg: fg)
                        imStepRow(num: 2, title: "Find Blink → Open", fg: fg, bgTop: bgTop)
                        imStepConnector(fg: fg)
                        imStepRow(num: 3, title: "Toggle on", fg: fg, bgTop: bgTop)
                    }
                    .padding(16)
                    .background(fg.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .frame(width: 220)
                }
                .padding(.horizontal, 28)

                Spacer(minLength: 18)

                HStack(spacing: 14) {
                    pageButton(label: "Open Settings", icon: "gear", primary: true, fg: fg, bgTop: bgTop) {
                        NSApp.activate(ignoringOtherApps: true)
                        PermissionManager.requestInputMonitoringAccess()
                        PermissionManager.openInputMonitoringSettings()
                    }
                    pageButton(label: "I've granted access", icon: "checkmark.circle.fill", primary: false, fg: fg, bgTop: bgTop) {
                        checkGrant()
                    }
                }

                // Basic-mode opt-out shown in both modes. In recovery
                // it lets the user defer the IM re-grant and run the
                // basic timer until they're ready to deal with TCC. The
                // copy varies slightly so the action's intent reads
                // right in each context.
                Button {
                    BlinkLog.permission.info("IM step (mode=\(mode)): user chose basic mode")
                    stopPolling()
                    onComplete(true)
                } label: {
                    Text(mode == .staleGrant
                         ? "Skip for now — use basic timer"
                         : "Continue with basic timer (no smart timing)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(fg.opacity(0.65))
                        .underline()
                }
                .buttonStyle(.plain)
                .padding(.top, 16)
            }
            .padding(.top, outerVPad)
            .padding(.bottom, outerVPad)
        }
    }

    private func backButton(fg: Color) -> some View {
        Button {
            stopPolling()
            onBack?()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                Text("Microphone")
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundStyle(fg)
        }
        .buttonStyle(.plain)
        .padding(.top, 20)
        .padding(.leading, 24)
    }

    // MARK: - Grant polling + manual check

    private func initializeFromCurrentStatus() {
        if PermissionManager.isPermissionGranted() {
            BlinkLog.permission.info("Onboarding IM step: already granted on appear — auto-completing")
            onComplete(false)
        }
    }

    private func startPolling() {
        guard pollTimer == nil else { return }
        pollTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            DispatchQueue.main.async {
                if PermissionManager.isPermissionGranted() {
                    BlinkLog.permission.info("Onboarding IM step: poll detected grant — completing")
                    stopPolling()
                    onComplete(false)
                }
            }
        }
    }

    private func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    private func checkGrant() {
        retryAttempts += 1
        BlinkLog.permission.info("Onboarding IM step: user tapped 'I've granted access' (attempt \(retryAttempts))")
        if PermissionManager.isPermissionGranted() {
            stopPolling()
            onComplete(false)
            return
        }
        // Brief retry — TCC grant can take a moment to propagate
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if PermissionManager.isPermissionGranted() {
                stopPolling()
                onComplete(false)
            }
        }
    }

    // MARK: - Step list helpers

    private func imStepRow(num: Int, title: String, fg: Color, bgTop: Color) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(fg).frame(width: 24, height: 24)
                Text("\(num)").font(.system(size: 13, weight: .bold)).foregroundStyle(bgTop)
            }
            Text(title).font(.system(size: 13, weight: .bold)).foregroundStyle(fg)
        }
        .padding(.vertical, 6)
    }

    private func imStepConnector(fg: Color) -> some View {
        Rectangle().fill(fg.opacity(0.3)).frame(width: 2, height: 8).padding(.leading, 11)
    }

    private func pageButton(label: String, icon: String?, primary: Bool, fg: Color, bgTop: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon { Image(systemName: icon).font(.system(size: 13, weight: .semibold)) }
                Text(label).font(.system(size: 15, weight: .bold))
            }
            .foregroundStyle(primary ? bgTop : fg)
            .frame(height: 44)
            .padding(.horizontal, 26)
            .background(primary ? fg : fg.opacity(0.22))
            .clipShape(Capsule())
            .shadow(color: primary ? .black.opacity(0.18) : .clear, radius: primary ? 8 : 0, y: primary ? 4 : 0)
        }
        .buttonStyle(.plain)
    }
}

#Preview("Peach") {
    InputMonitoringPermissionPage(theme: .peach, onBack: {}, onComplete: { _ in })
        .frame(width: 900, height: 650)
}

#Preview("Midnight") {
    InputMonitoringPermissionPage(theme: .midnight, onBack: {}, onComplete: { _ in })
        .frame(width: 900, height: 650)
        .preferredColorScheme(.dark)
}
