import SwiftUI

/// Explainer dialog shown immediately after Input Monitoring is granted,
/// before the engine starts. Pre-explains why we want microphone access
/// (call/meeting detection) and what we DON'T do with it, then either
/// triggers the system TCC dialog via `AVCaptureDevice.requestAccess`
/// (on "Grant Access") or skips the feature entirely (on "Skip").
///
/// We show this ourselves so users see a friendly rationale before
/// macOS's terse "Blink would like to access the microphone" prompt.
struct MicrophonePermissionView: View {
    let theme: BlinkTheme
    let onGrant: () -> Void
    let onSkip: () -> Void
    @Environment(\.colorScheme) private var colorScheme

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
                // Header
                VStack(spacing: 6) {
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
                .frame(maxWidth: .infinity)
                .padding(.top, 24)
                .padding(.bottom, 18)

                // Rationale bullets
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
                .padding(.horizontal, 32)

                Spacer()

                // Buttons
                HStack(spacing: 12) {
                    Button {
                        onSkip()
                    } label: {
                        Text("Skip")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(fg)
                            .frame(height: 40)
                            .padding(.horizontal, 24)
                            .background(fg.opacity(0.18))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)

                    Button {
                        onGrant()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "mic.fill")
                                .font(.system(size: 12, weight: .semibold))
                            Text("Grant Access")
                                .font(.system(size: 14, weight: .bold))
                        }
                        .foregroundStyle(bgTop)
                        .frame(height: 40)
                        .padding(.horizontal, 24)
                        .background(fg)
                        .clipShape(Capsule())
                        .shadow(color: .black.opacity(0.2), radius: 10, y: 5)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.bottom, 28)
            }
        }
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

#Preview("Microphone — Peach") {
    MicrophonePermissionView(theme: .peach, onGrant: {}, onSkip: {})
        .frame(width: 560, height: 440)
}

#Preview("Microphone — Midnight") {
    MicrophonePermissionView(theme: .midnight, onGrant: {}, onSkip: {})
        .frame(width: 560, height: 440)
        .preferredColorScheme(.dark)
}
