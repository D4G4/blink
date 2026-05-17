import SwiftUI

private let allThemesWithDark: [(String, BlinkTheme)] = [
    ("Peach", .peach),
    ("Midnight", .midnight),
    ("Sage", .sage),
    ("Sand", .sand),
    ("Mono", .mono),
    ("Dark Overlay", .dark),
]

// MARK: - Break Timer Previews

#Preview("Break Timer — All Themes — Light") {
    ScrollView {
        VStack(spacing: 20) {
            ForEach(allThemesWithDark, id: \.0) { name, theme in
                VStack(spacing: 4) {
                    Text(name).font(.caption).foregroundStyle(.secondary)
                    BreakPhaseView(theme: theme, model: BreakPhaseModel(), onComplete: {}, onSkip: {})
                        .frame(width: 500, height: 420)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .padding(20)
    }
    .frame(width: 560, height: 2800)
    .preferredColorScheme(.light)
}

#Preview("Break Timer — All Themes — Dark") {
    ScrollView {
        VStack(spacing: 20) {
            ForEach(allThemesWithDark, id: \.0) { name, theme in
                VStack(spacing: 4) {
                    Text(name).font(.caption).foregroundStyle(.secondary)
                    BreakPhaseView(theme: theme, model: BreakPhaseModel(), onComplete: {}, onSkip: {})
                        .frame(width: 500, height: 420)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .padding(20)
    }
    .frame(width: 560, height: 2800)
    .preferredColorScheme(.dark)
}

// MARK: - Countdown Previews

#Preview("Countdown — All Themes — Light") {
    ScrollView {
        VStack(spacing: 16) {
            ForEach(allThemesWithDark, id: \.0) { name, theme in
                VStack(spacing: 4) {
                    Text(name).font(.caption).foregroundStyle(.secondary)
                    CountdownPhaseView(theme: theme, onCountdownDone: {}, onSkip: {})
                        .frame(width: 400, height: 280)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .padding(20)
    }
    .frame(width: 460, height: 2000)
    .preferredColorScheme(.light)
}

#Preview("Countdown — All Themes — Dark") {
    ScrollView {
        VStack(spacing: 16) {
            ForEach(allThemesWithDark, id: \.0) { name, theme in
                VStack(spacing: 4) {
                    Text(name).font(.caption).foregroundStyle(.secondary)
                    CountdownPhaseView(theme: theme, onCountdownDone: {}, onSkip: {})
                        .frame(width: 400, height: 280)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .padding(20)
    }
    .frame(width: 460, height: 2000)
    .preferredColorScheme(.dark)
}

// MARK: - Toast Previews

#Preview("Toast — All Themes — Light") {
    ScrollView {
        VStack(spacing: 16) {
            ForEach(allThemesWithDark, id: \.0) { name, theme in
                VStack(spacing: 4) {
                    Text(name).font(.caption).foregroundStyle(.secondary)
                    ToastView(theme: theme, onDone: {})
                        .frame(width: 280, height: 72)
                }
            }
        }
        .padding(20)
    }
    .frame(width: 340, height: 700)
    .preferredColorScheme(.light)
}

#Preview("Toast — All Themes — Dark") {
    ScrollView {
        VStack(spacing: 16) {
            ForEach(allThemesWithDark, id: \.0) { name, theme in
                VStack(spacing: 4) {
                    Text(name).font(.caption).foregroundStyle(.secondary)
                    ToastView(theme: theme, onDone: {})
                        .frame(width: 280, height: 72)
                }
            }
        }
        .padding(20)
    }
    .frame(width: 340, height: 700)
    .preferredColorScheme(.dark)
}

// MARK: - Timer Extended Toast Previews

#Preview("Timer Extended — All Themes — Light") {
    ScrollView {
        VStack(spacing: 16) {
            ForEach(allThemesWithDark, id: \.0) { name, theme in
                VStack(spacing: 4) {
                    Text(name).font(.caption).foregroundStyle(.secondary)
                    TimerExtendedToastView(theme: theme, onDismiss: {}, onTakeBreak: {})
                        .frame(width: 280)
                }
            }
        }
        .padding(20)
    }
    .frame(width: 340, height: 700)
    .preferredColorScheme(.light)
}

#Preview("Timer Extended — All Themes — Dark") {
    ScrollView {
        VStack(spacing: 16) {
            ForEach(allThemesWithDark, id: \.0) { name, theme in
                VStack(spacing: 4) {
                    Text(name).font(.caption).foregroundStyle(.secondary)
                    TimerExtendedToastView(theme: theme, onDismiss: {}, onTakeBreak: {})
                        .frame(width: 280)
                }
            }
        }
        .padding(20)
    }
    .frame(width: 340, height: 700)
    .preferredColorScheme(.dark)
}

// MARK: - Flow Nudge Toast Previews

#Preview("Flow Nudge — All Themes — Light") {
    ScrollView {
        VStack(spacing: 16) {
            ForEach(allThemesWithDark, id: \.0) { name, theme in
                VStack(spacing: 4) {
                    Text(name).font(.caption).foregroundStyle(.secondary)
                    FlowNudgeToastView(theme: theme, message: "Focused — extended 10 min", onDismiss: {}, onTakeBreak: {})
                        .frame(width: 320)
                }
            }
        }
        .padding(20)
    }
    .frame(width: 380, height: 700)
    .preferredColorScheme(.light)
}

#Preview("Flow Nudge — All Themes — Dark") {
    ScrollView {
        VStack(spacing: 16) {
            ForEach(allThemesWithDark, id: \.0) { name, theme in
                VStack(spacing: 4) {
                    Text(name).font(.caption).foregroundStyle(.secondary)
                    FlowNudgeToastView(theme: theme, message: "Focused — extended 10 min", onDismiss: {}, onTakeBreak: {})
                        .frame(width: 320)
                }
            }
        }
        .padding(20)
    }
    .frame(width: 380, height: 700)
    .preferredColorScheme(.dark)
}
