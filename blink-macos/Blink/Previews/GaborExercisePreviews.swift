import SwiftUI

private let allThemes: [BlinkTheme] = [.peach, .midnight, .sage, .sand, .mono]

#Preview("GaborExercise — All Themes — Light") {
    ScrollView {
        VStack(spacing: 20) {
            ForEach(allThemes) { theme in
                VStack(spacing: 4) {
                    Text(theme.name).font(.caption).foregroundStyle(.secondary)
                    GaborExerciseView(state: GaborExerciseState(), theme: theme, onDismiss: {})
                        .frame(width: 500, height: 400)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .padding(20)
    }
    .frame(width: 560, height: 2300) 
    .preferredColorScheme(.light)
}

/// Full-size, fully interactive preview. Lands at `.ready` (the
/// exercise picker) so you can click through the whole flow without
/// launching the app:
///   ready → pick exercise → instructions → start trials → feedback →
///   continue → complete screen.
/// Trial timing uses real Timers and the adaptive staircase responds
/// to your clicks just like the live app.
#Preview("GaborExercise — Interactive (Full Flow)") {
    let state = GaborExerciseState()
    state.phase = .ready
    return GaborExerciseView(state: state, theme: .peach, onDismiss: {})
        .frame(width: 900, height: 700)
        .preferredColorScheme(.dark)
}

/// Preview that lands directly on the Instructions phase for the
/// Orientation exercise — so the new "What the tilts look like"
/// reference patches are visible without clicking through the
/// disclaimer + ready picker.
#Preview("GaborExercise — Instructions (Orientation)") {
    let state = GaborExerciseState()
    state.exerciseType = .orientationDiscrimination
    state.phase = .instructions
    return GaborExerciseView(state: state, theme: .peach, onDismiss: {})
        .frame(width: 720, height: 900)
        .preferredColorScheme(.dark)
}

#Preview("GaborExercise — Instructions (Flanker)") {
    let state = GaborExerciseState()
    state.exerciseType = .flankerMasking
    state.phase = .instructions
    return GaborExerciseView(state: state, theme: .peach, onDismiss: {})
        .frame(width: 720, height: 900)
        .preferredColorScheme(.dark)
}

#Preview("GaborExercise — All Themes — Dark") {
    ScrollView {
        VStack(spacing: 20) {
            ForEach(allThemes) { theme in
                VStack(spacing: 4) {
                    Text(theme.name).font(.caption).foregroundStyle(.secondary)
                    GaborExerciseView(state: GaborExerciseState(), theme: theme, onDismiss: {})
                        .frame(width: 500, height: 400)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .padding(20)
    }
    .frame(width: 560, height: 2300)
    .preferredColorScheme(.dark)
}
