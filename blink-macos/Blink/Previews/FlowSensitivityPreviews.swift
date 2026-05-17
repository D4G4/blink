import SwiftUI

private let allThemes: [BlinkTheme] = [.peach, .midnight, .sage, .sand, .mono]

private struct FlowSensitivityPreviewWrapper: View {
    let theme: BlinkTheme
    let style: FlowSensitivityView.Style
    @State private var sensitivity: Double = 0.7
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        FlowSensitivityView(
            sensitivity: $sensitivity,
            accentColor: theme.accent(for: colorScheme),
            foregroundColor: style == .settings ? .primary : theme.onBackgroundText(for: colorScheme),
            style: style
        )
    }
}

#Preview("FlowSensitivity Settings — All Themes — Light") {
    ScrollView {
        VStack(spacing: 20) {
            ForEach(allThemes) { theme in
                VStack(spacing: 4) {
                    Text(theme.name).font(.caption).foregroundStyle(.secondary)
                    FlowSensitivityPreviewWrapper(theme: theme, style: .settings)
                        .frame(width: 400)
                        .padding(16)
                        .background(Color(nsColor: .windowBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .padding(20)
    }
    .frame(width: 460, height: 1400)
    .preferredColorScheme(.light)
}

#Preview("FlowSensitivity Settings — All Themes — Dark") {
    ScrollView {
        VStack(spacing: 20) {
            ForEach(allThemes) { theme in
                VStack(spacing: 4) {
                    Text(theme.name).font(.caption).foregroundStyle(.secondary)
                    FlowSensitivityPreviewWrapper(theme: theme, style: .settings)
                        .frame(width: 400)
                        .padding(16)
                        .background(Color(nsColor: .windowBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .padding(20)
    }
    .frame(width: 460, height: 1400)
    .preferredColorScheme(.dark)
}

#Preview("FlowSensitivity Onboarding — All Themes — Light") {
    ScrollView {
        VStack(spacing: 20) {
            ForEach(allThemes) { theme in
                VStack(spacing: 4) {
                    Text(theme.name).font(.caption).foregroundStyle(.secondary)
                    FlowSensitivityPreviewWrapper(theme: theme, style: .onboarding)
                        .frame(width: 400)
                        .padding(16)
                        .background(theme.backgroundGradient)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .padding(20)
    }
    .frame(width: 460, height: 1400)
    .preferredColorScheme(.light)
}
