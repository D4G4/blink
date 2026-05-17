import SwiftUI

private let allThemes: [BlinkTheme] = [.peach, .midnight, .sage, .sand, .mono]

#Preview("Research — All Themes — Light") {
    ScrollView {
        VStack(spacing: 20) {
            ForEach(allThemes) { theme in
                VStack(spacing: 4) {
                    Text(theme.name).font(.caption).foregroundStyle(.secondary)
                    ResearchView(theme: theme, onDismiss: {})
                        .frame(width: 500, height: 580)
                        .background(Color(nsColor: .windowBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .padding(20)
    }
    .frame(width: 560, height: 3200)
    .preferredColorScheme(.light)
}

#Preview("Research — All Themes — Dark") {
    ScrollView {
        VStack(spacing: 20) {
            ForEach(allThemes) { theme in
                VStack(spacing: 4) {
                    Text(theme.name).font(.caption).foregroundStyle(.secondary)
                    ResearchView(theme: theme, onDismiss: {})
                        .frame(width: 500, height: 580)
                        .background(Color(nsColor: .windowBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .padding(20)
    }
    .frame(width: 560, height: 3200)
    .preferredColorScheme(.dark)
}
