import SwiftUI

// Dev-only harness (NOT shipped — see the GaborDev target in project.yml).
// Launches straight into the Gabor exercise UI in a normal window, bypassing
// the menu bar, onboarding, permissions, and monitoring, with a live theme
// switcher and a restart button. Build & run the "GaborDev" scheme (Cmd+R) to
// eyeball and click through the exercise.
@main
struct GaborDevApp: App {
    var body: some Scene {
        WindowGroup("Gabor Exercise — Dev") {
            GaborDevRoot()
                .frame(minWidth: 940, minHeight: 720)
        }
        .windowResizability(.contentSize)
    }
}

private struct GaborDevRoot: View {
    @StateObject private var state = GaborDevRoot.makeState()
    @State private var theme: BlinkTheme = .peach

    private let themes: [BlinkTheme] = [.peach, .midnight, .sage, .sand, .mono]

    /// Land on the picker instead of the disclaimer gate, so testing is quick.
    private static func makeState() -> GaborExerciseState {
        let s = GaborExerciseState()
        s.phase = .ready
        return s
    }

    var body: some View {
        VStack(spacing: 0) {
            // Dev toolbar — theme switcher + restart. Not part of the shipped UI.
            HStack(spacing: 8) {
                Text("DEV")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.secondary)
                ForEach(themes) { t in
                    Button(t.name) { theme = t }
                        .controlSize(.small)
                        .buttonStyle(.borderedProminent)
                        .tint(t.id == theme.id ? Color.accentColor : Color.gray.opacity(0.35))
                }
                Spacer()
                Button("Restart session") { state.returnToPicker() }
                    .controlSize(.small)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color(nsColor: .windowBackgroundColor))

            GaborExerciseView(
                state: state,
                theme: theme,
                onDismiss: { state.returnToPicker() }
            )
        }
    }
}
