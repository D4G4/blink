import SwiftUI

private let allThemes: [BlinkTheme] = [.peach, .midnight, .sage, .sand, .mono]

#Preview("Settings — All Themes — Light") {
    ScrollView {
        VStack(spacing: 20) {
            ForEach(allThemes) { theme in
                VStack(spacing: 4) {
                    Text(theme.name).font(.caption).foregroundStyle(.secondary)
                    SettingsView(appState: AppState(preview: true))
                        .environmentObject(ThemeManager.preview(theme))
                        .frame(width: 440, height: 380)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .shadow(radius: 4)
                }
            }
        }
        .padding(20)
    }
    .frame(width: 500, height: 2200)
    .preferredColorScheme(.light)
}

#Preview("Settings — All Themes — Dark") {
    ScrollView {
        VStack(spacing: 20) {
            ForEach(allThemes) { theme in
                VStack(spacing: 4) {
                    Text(theme.name).font(.caption).foregroundStyle(.secondary)
                    SettingsView(appState: AppState(preview: true))
                        .environmentObject(ThemeManager.preview(theme))
                        .frame(width: 440, height: 380)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .shadow(radius: 4)
                }
            }
        }
        .padding(20)
    }
    .frame(width: 500, height: 2200)
    .preferredColorScheme(.dark)
}
