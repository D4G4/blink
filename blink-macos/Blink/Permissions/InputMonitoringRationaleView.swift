import SwiftUI

/// "Why does Blink need Input Monitoring?" sheet — shown when the user
/// taps the question button on the IM step of the wizard. Explains what
/// we actually do with the access, what we explicitly DON'T do, and why
/// macOS requires this permission specifically.
struct InputMonitoringRationaleView: View {
    let theme: BlinkTheme
    let onDismiss: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        // Two text colors — hero for the header (icon, title, subtitle,
        // primary button) and body for the dense rationale rows. Matches
        // the split used in MicrophonePermissionPage /
        // InputMonitoringPermissionPage.
        let heroFg = theme.onBackgroundText(for: colorScheme)
        let bodyFg = theme.onBackgroundBodyText(for: colorScheme)
        let bgTop = theme.backgroundTop(for: colorScheme)

        ZStack {
            theme.backgroundGradient(for: colorScheme)
                .ignoresSafeArea()

            RadialGradient(
                colors: [heroFg.opacity(0.1), .clear],
                center: .top,
                startRadius: 50,
                endRadius: 400
            )

            VStack(spacing: 0) {
                // Header
                VStack(spacing: 6) {
                    Image(systemName: "questionmark.circle.fill")
                        .font(.system(size: 26, weight: .light))
                        .foregroundStyle(heroFg)
                        .padding(.bottom, 4)
                    Text("Why Input Monitoring?")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(heroFg)
                    Text("What Blink reads, what it doesn't, and why this permission")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(heroFg.opacity(0.85))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
                .padding(.top, 24)
                .padding(.bottom, 20)

                // Rationale
                VStack(alignment: .leading, spacing: 14) {
                    rationaleRow(
                        icon: "waveform",
                        title: "What it reads",
                        body: "Only timing — when keys are pressed, when the mouse moves, scroll deltas, click counts. This is the raw signal Blink uses to score your focus state.",
                        fg: bodyFg
                    )
                    rationaleRow(
                        icon: "eye.slash.fill",
                        title: "What it does NOT read",
                        body: "Never the actual keys you press, never window contents, never URLs or filenames. Blink doesn't know if you typed \"hello\" or random characters — only that you typed.",
                        fg: bodyFg
                    )
                    rationaleRow(
                        icon: "brain.head.profile",
                        title: "Why we need this signal",
                        body: "Smart break timing depends on knowing when you're in deep flow vs idle vs context-switching. A dumb 20-min timer would interrupt you mid-thought. Typing rhythm + mouse activity is what makes the difference.",
                        fg: bodyFg
                    )
                    rationaleRow(
                        icon: "lock.shield.fill",
                        title: "Why a system permission",
                        body: "macOS requires Input Monitoring to observe keystroke events globally, even just for timing. There is no lower-permission API for this. Nothing leaves your Mac — no telemetry, no network calls, no storage.",
                        fg: bodyFg
                    )
                }
                .frame(maxWidth: 480)
                .padding(.horizontal, 28)

                Spacer()

                // Dismiss
                Button {
                    onDismiss()
                } label: {
                    Text("Got it")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(bgTop)
                        .frame(width: 140, height: 40)
                        .background(heroFg)
                        .clipShape(Capsule())
                        .shadow(color: .black.opacity(0.2), radius: 10, y: 5)
                }
                .buttonStyle(.plain)
                .padding(.bottom, 24)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private func rationaleRow(icon: String, title: String, body: String, fg: Color) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(fg)
                .frame(width: 22, height: 22)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(fg)
                Text(body)
                    .font(.system(size: 12))
                    .foregroundStyle(fg.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }
}

#Preview("Rationale — Peach") {
    InputMonitoringRationaleView(theme: .peach, onDismiss: {})
        .frame(width: 540, height: 520)
}

#Preview("Rationale — Midnight") {
    InputMonitoringRationaleView(theme: .midnight, onDismiss: {})
        .frame(width: 540, height: 520)
        .preferredColorScheme(.dark)
}
