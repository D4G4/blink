import SwiftUI

private let allThemes: [BlinkTheme] = [.peach, .midnight, .sage, .sand, .mono]

#Preview("Mic Permission — All Themes — Light") {
    ScrollView {
        VStack(spacing: 20) {
            ForEach(allThemes) { theme in
                VStack(spacing: 4) {
                    Text(theme.name).font(.caption).foregroundStyle(.secondary)
                    MicrophonePermissionPage(theme: theme, onAdvance: {})
                        .frame(width: 500, height: 600)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .padding(20)
    }
    .frame(width: 560, height: 3200)
    .preferredColorScheme(.light)
}

#Preview("IM Permission — Onboarding mode — All Themes") {
    ScrollView {
        VStack(spacing: 20) {
            ForEach(allThemes) { theme in
                VStack(spacing: 4) {
                    Text(theme.name).font(.caption).foregroundStyle(.secondary)
                    InputMonitoringPermissionPage(theme: theme, mode: .standard, onComplete: { _ in })
                        .frame(width: 700, height: 600)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .padding(20)
    }
    .frame(width: 760, height: 3200)
}

#Preview("IM Permission — Stale-grant Recovery — All Themes") {
    ScrollView {
        VStack(spacing: 20) {
            ForEach(allThemes) { theme in
                VStack(spacing: 4) {
                    Text(theme.name).font(.caption).foregroundStyle(.secondary)
                    InputMonitoringPermissionPage(theme: theme, mode: .staleGrant, onComplete: { _ in })
                        .frame(width: 700, height: 600)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .padding(20)
    }
    .frame(width: 760, height: 3200)
}
