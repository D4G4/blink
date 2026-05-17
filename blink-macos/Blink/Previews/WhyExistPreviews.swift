import SwiftUI

private let allThemes: [BlinkTheme] = [.peach, .midnight, .sage, .sand, .mono]

#Preview("WhyExist — All Themes — Light") {
    ScrollView {
        VStack(spacing: 20) {
            ForEach(allThemes) { theme in
                VStack(spacing: 4) {
                    Text(theme.name).font(.caption).foregroundStyle(.secondary)
                    WhyExistView(theme: theme, onDismiss: {})
                        .frame(width: 500, height: 420)
                        .background(Color(nsColor: .windowBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .padding(20)
    }
    .frame(width: 560, height: 2400)
    .preferredColorScheme(.light)
}

#Preview("WhyExist — All Themes — Dark") {
    ScrollView {
        VStack(spacing: 20) {
            ForEach(allThemes) { theme in
                VStack(spacing: 4) {
                    Text(theme.name).font(.caption).foregroundStyle(.secondary)
                    WhyExistView(theme: theme, onDismiss: {})
                        .frame(width: 500, height: 420)
                        .background(Color(nsColor: .windowBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .padding(20)
    }
    .frame(width: 560, height: 2400)
    .preferredColorScheme(.dark)
}
