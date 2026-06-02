import SwiftUI
import AVFoundation

/// Onboarding page 3: microphone permission step.
///
/// Replaces the standalone PermissionWizardView's mic step — inlined here
/// so the whole permission flow lives in the same onboarding window (no
/// jarring window change from onboarding to a separate wizard).
///
/// State machine:
///   - notDetermined  → "Microphone Access" initial UI (Skip / Grant Access)
///   - granted        → auto-advance to next page (onAdvance)
///   - denied         → "Microphone Access Denied" recovery UI (Open Settings / Continue)
///
/// When the user taps Open Settings on the denied state, we poll TCC
/// every 2s so the page auto-advances if they toggle Blink on in
/// Privacy → Microphone without coming back to click Continue.
struct MicrophonePermissionPage: View {
    let theme: BlinkTheme
    /// Optional back-navigation hook. When set, renders a back button in
    /// the top-left that returns to the previous step (the detection-mode
    /// choice page in PermissionFlow). Nil in contexts where there's
    /// nowhere to go back to.
    var onBack: (() -> Void)? = nil
    /// Called when this step is resolved (granted, skipped, or post-denial continue).
    let onAdvance: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var deniedInSession: Bool = false
    @State private var pollTimer: Timer?

    var body: some View {
        GeometryReader { proxy in
            content(availableHeight: proxy.size.height)
        }
        .onAppear { initializeFromCurrentStatus() }
        .onDisappear { stopPolling() }
    }

    @ViewBuilder
    private func content(availableHeight: CGFloat) -> some View {
        let isCompact = availableHeight < 700
        let iconSize: CGFloat = isCompact ? 38 : 48
        let titleSize: CGFloat = isCompact ? 24 : 28
        let outerVPad: CGFloat = isCompact ? 20 : 40

        // Two text colors per page:
        //   heroFg — title, subtitle, button styling. Matches onboarding
        //   pages so the visual identity carries through (white on warm
        //   themes like Peach, dark on pastel themes like Sage / Sand).
        //   bodyFg — rationale rows / captions. Drops to the readable
        //   dark variant on warm themes so dense prose isn't washed out.
        let heroFg = theme.onBackgroundText(for: colorScheme)
        let bodyFg = theme.onBackgroundBodyText(for: colorScheme)
        let bgTop = theme.backgroundTop(for: colorScheme)

        ZStack(alignment: .topLeading) {
            theme.backgroundGradient(for: colorScheme).ignoresSafeArea()

            // Back button (top-left) — returns to the detection-mode
            // choice page so the user can switch to Simple after seeing
            // what Smart involves. Only rendered when onBack is wired;
            // contexts that present this page standalone (none today,
            // but kept conditional for safety) get no back affordance.
            if let onBack {
                backButton(heroFg: heroFg, onTap: onBack)
                    .padding(.top, 16)
                    .padding(.leading, 18)
            }

            // `frame(maxWidth: .infinity, maxHeight: .infinity)` forces
            // the content VStack to fill the whole ZStack. Without it,
            // SwiftUI takes the VStack's intrinsic width (collapsed to
            // its widest child, ~540pt) and the ZStack's .topLeading
            // alignment pins the whole pile to the upper-left corner.
            VStack(spacing: 0) {
                if deniedInSession {
                    deniedStep(heroFg: heroFg, bodyFg: bodyFg, bgTop: bgTop, iconSize: iconSize, titleSize: titleSize)
                } else {
                    initialStep(heroFg: heroFg, bodyFg: bodyFg, bgTop: bgTop, iconSize: iconSize, titleSize: titleSize)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.top, outerVPad)
            .padding(.bottom, outerVPad)
        }
    }

    // MARK: - Initial step

    private func initialStep(heroFg: Color, bodyFg: Color, bgTop: Color, iconSize: CGFloat, titleSize: CGFloat) -> some View {
        VStack(spacing: 0) {
            Image(systemName: "mic.fill")
                .font(.system(size: iconSize, weight: .light))
                .foregroundStyle(heroFg)
                .padding(.bottom, 10)

            Text("Microphone Access")
                .font(.system(size: titleSize, weight: .bold, design: .rounded))
                .foregroundStyle(heroFg)

            Text("So breaks don't interrupt your calls")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(heroFg.opacity(0.85))
                .padding(.top, 4)

            Spacer(minLength: 24)

            VStack(alignment: .leading, spacing: 26) {
                rationaleRow(
                    icon: "checkmark.circle.fill",
                    title: "What it's for",
                    body: "Detect when an app is using your mic so the break timer auto-pauses during meetings and calls.",
                    fg: bodyFg
                )
                rationaleRow(
                    icon: "eye.slash.fill",
                    title: "What we don't do",
                    body: "We only check whether the mic is in use — we never record, transmit, or store any audio.",
                    fg: bodyFg
                )
                rationaleRow(
                    icon: "hand.raised.fill",
                    title: "If you skip",
                    body: "Everything else still works. The timer just won't auto-pause during calls — you can manually pause from the menu bar.",
                    fg: bodyFg
                )
            }
            .frame(maxWidth: 540)
            .padding(.horizontal, 28)

            Spacer(minLength: 24)

            HStack(spacing: 14) {
                pageButton(label: "Skip", icon: nil, primary: false, fg: heroFg, bgTop: bgTop) {
                    BlinkLog.permission.info("Onboarding mic step: user skipped")
                    onAdvance()
                }
                pageButton(label: "Grant Access", icon: "mic.fill", primary: true, fg: heroFg, bgTop: bgTop) {
                    Task { @MainActor in
                        let granted = await PermissionManager.requestMicrophoneAccess()
                        BlinkLog.permission.info("Onboarding mic step: requestAccess resolved granted=\(granted)")
                        if granted {
                            onAdvance()
                        } else {
                            withAnimation { deniedInSession = true }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Denied step

    private func deniedStep(heroFg: Color, bodyFg: Color, bgTop: Color, iconSize: CGFloat, titleSize: CGFloat) -> some View {
        VStack(spacing: 0) {
            Image(systemName: "mic.slash.fill")
                .font(.system(size: iconSize, weight: .light))
                .foregroundStyle(heroFg)
                .padding(.bottom, 10)

            Text("Microphone Access Denied")
                .font(.system(size: titleSize, weight: .bold, design: .rounded))
                .foregroundStyle(heroFg)

            Text("macOS won't ask again — you can change this in Settings")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(heroFg.opacity(0.85))
                .padding(.top, 4)

            Spacer(minLength: 24)

            VStack(alignment: .leading, spacing: 14) {
                rationaleRow(
                    icon: "info.circle.fill",
                    title: "If this was a misclick",
                    body: "Open System Settings → Privacy & Security → Microphone, toggle Blink on, then click Continue below.",
                    fg: bodyFg
                )
                rationaleRow(
                    icon: "hand.raised.fill",
                    title: "If you meant to deny",
                    body: "Click Continue to move on. Everything else still works — the timer just won't auto-pause during calls.",
                    fg: bodyFg
                )
            }
            .frame(maxWidth: 540)
            .padding(.horizontal, 28)

            Spacer(minLength: 24)

            HStack(spacing: 14) {
                pageButton(label: "Open Settings", icon: "gear", primary: false, fg: heroFg, bgTop: bgTop) {
                    PermissionManager.openMicrophoneSettings()
                    startPolling()
                }
                pageButton(label: "Continue", icon: "arrow.right", primary: true, fg: heroFg, bgTop: bgTop) {
                    BlinkLog.permission.info("Onboarding mic step: user continued past denial")
                    stopPolling()
                    onAdvance()
                }
            }
        }
    }

    // MARK: - Polling

    private func initializeFromCurrentStatus() {
        let status = PermissionManager.microphoneAuthorizationStatus()
        switch status {
        case .authorized:
            BlinkLog.permission.info("Onboarding mic step: already authorized — auto-advancing")
            onAdvance()
        case .denied, .restricted:
            BlinkLog.permission.info("Onboarding mic step: previously denied — showing denial UI")
            deniedInSession = true
        case .notDetermined:
            break
        @unknown default:
            break
        }
    }

    private func startPolling() {
        guard pollTimer == nil else { return }
        BlinkLog.permission.info("Onboarding mic step: starting grant polling (every 2s)")
        pollTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            DispatchQueue.main.async {
                if PermissionManager.microphoneAuthorizationStatus() == .authorized {
                    BlinkLog.permission.info("Onboarding mic step: poll detected grant — advancing")
                    stopPolling()
                    onAdvance()
                }
            }
        }
    }

    private func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    // MARK: - Reusable rows + buttons

    private func rationaleRow(icon: String, title: String, body: String, fg: Color) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(fg)
                .frame(width: 24, height: 24)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 18, weight: .bold)).foregroundStyle(fg)
                Text(body).font(.system(size: 15)).foregroundStyle(fg.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
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

    private func backButton(heroFg: Color, onTap: @escaping () -> Void) -> some View {
        Button(action: onTap) {
            HStack(spacing: 4) {
                Image(systemName: "chevron.left").font(.system(size: 12, weight: .bold))
                Text("Back").font(.system(size: 13, weight: .medium))
            }
            .foregroundStyle(heroFg)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(heroFg.opacity(0.15))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

#Preview("Peach") {
    MicrophonePermissionPage(theme: .peach, onAdvance: {})
        .frame(width: 900, height: 650)
}

#Preview("Sage") {
    MicrophonePermissionPage(theme: .sage, onAdvance: {})
        .frame(width: 900, height: 650)
}
