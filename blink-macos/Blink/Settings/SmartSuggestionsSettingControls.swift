import SwiftUI

/// Toggle + caption + "Learn more" button + help-sheet trigger for the
/// Smart Break Suggestions feature. Extracted from `SettingsView` so a
/// snapshot test can render it directly — SettingsView itself wraps its
/// content in a ScrollView that `ImageRenderer` doesn't measure, which
/// makes section-level visuals invisible in snapshots.
struct SmartSuggestionsSettingControls: View {
    let theme: BlinkTheme
    let accentColor: Color
    @Binding var isOn: Bool
    @Binding var showHelp: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Image(systemName: "sparkles")
                    .font(.system(size: 17))
                    .foregroundStyle(accentColor)
                    .symbolRenderingMode(.hierarchical)
                    .frame(width: 32, alignment: .center)
                Toggle("Smart break suggestions", isOn: $isOn)
                    .font(.system(size: 15))
                    .toggleStyle(ThemedToggleStyle(theme: theme))
            }

            // Caption indents past the icon column so it aligns with the
            // toggle label, not the icon. Same alignment as the other
            // captions in General.
            Text("Replaces the eye-rest title with a context-aware action (drink water, get up, breathe\u{2026}) when it fits the moment. Breaks get 5 extra seconds when a suggestion is shown so you have time to read it.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.leading, 46)

            Button {
                UIActionLogger.buttonTapped("Learn more about smart break suggestions")
                showHelp = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 11))
                    Text("Learn more")
                        .font(.system(size: 12))
                }
                .foregroundStyle(accentColor)
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
            .padding(.leading, 42)
            .sheet(isPresented: $showHelp) {
                BreakSuggestionsHelpView(theme: theme) {
                    showHelp = false
                }
            }
        }
    }
}

#Preview("Peach light - on") {
    SmartSuggestionsSettingControls(
        theme: .peach,
        accentColor: BlinkTheme.peach.accent(for: .light),
        isOn: .constant(true),
        showHelp: .constant(false)
    )
    .padding(20)
    .frame(width: 440)
}

#Preview("Midnight dark - off") {
    SmartSuggestionsSettingControls(
        theme: .midnight,
        accentColor: BlinkTheme.midnight.accent(for: .dark),
        isOn: .constant(false),
        showHelp: .constant(false)
    )
    .padding(20)
    .frame(width: 440)
    .preferredColorScheme(.dark)
}
