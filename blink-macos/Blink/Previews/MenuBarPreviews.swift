import SwiftUI

private let allThemes: [BlinkTheme] = [.peach, .midnight, .sage, .sand, .mono]

#Preview("MenuBar — All Themes — Light") {
    ScrollView {
        VStack(spacing: 20) {
            ForEach(allThemes) { theme in
                VStack(spacing: 4) {
                    Text(theme.name).font(.caption).foregroundStyle(.secondary)
                    MenuBarView(appState: AppState(preview: true))
                        .environmentObject(ThemeManager.preview(theme))
                        .environmentObject(UpdateChecker.shared)
                        .frame(width: 280)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .shadow(radius: 4)
                }
            }
        }
        .padding(20)
    }
    .frame(width: 340, height: 900)
    .preferredColorScheme(.light)
}

#Preview("MenuBar — All Themes — Dark") {
    ScrollView {
        VStack(spacing: 20) {
            ForEach(allThemes) { theme in
                VStack(spacing: 4) {
                    Text(theme.name).font(.caption).foregroundStyle(.secondary)
                    MenuBarView(appState: AppState(preview: true))
                        .environmentObject(ThemeManager.preview(theme))
                        .environmentObject(UpdateChecker.shared)
                        .frame(width: 280)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .shadow(radius: 4)
                }
            }
        }
        .padding(20)
    }
    .frame(width: 340, height: 900)
    .preferredColorScheme(.dark)
}
