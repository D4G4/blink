import SwiftUI

private let allThemes: [BlinkTheme] = [.peach, .midnight, .sage, .sand, .mono]

#Preview("PermissionOnboarding — All Themes — Light") {
    ScrollView {
        VStack(spacing: 20) {
            ForEach(allThemes) { theme in
                VStack(spacing: 4) {
                    Text(theme.name).font(.caption).foregroundStyle(.secondary)
                    PermissionOnboardingView(theme: theme, onContinue: {})
                        .frame(width: 500, height: 450)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .padding(20)
    }
    .frame(width: 560, height: 2600)
    .preferredColorScheme(.light)
}

#Preview("PermissionOnboarding — All Themes — Dark") {
    ScrollView {
        VStack(spacing: 20) {
            ForEach(allThemes) { theme in
                VStack(spacing: 4) {
                    Text(theme.name).font(.caption).foregroundStyle(.secondary)
                    PermissionOnboardingView(theme: theme, onContinue: {})
                        .frame(width: 500, height: 450)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .padding(20)
    }
    .frame(width: 560, height: 2600)
    .preferredColorScheme(.dark)
}

#Preview("PermissionGuide — All Themes — Light") {
    ScrollView {
        VStack(spacing: 20) {
            ForEach(allThemes) { theme in
                VStack(spacing: 4) {
                    Text(theme.name).font(.caption).foregroundStyle(.secondary)
                    PermissionGuideView(theme: theme, onOpenSettings: {}, onConfirmGranted: {})
                        .frame(width: 500, height: 580)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .padding(20)
    }
    .frame(width: 560, height: 3200)
    .preferredColorScheme(.light)
}

#Preview("PermissionGuide — All Themes — Dark") {
    ScrollView {
        VStack(spacing: 20) {
            ForEach(allThemes) { theme in
                VStack(spacing: 4) {
                    Text(theme.name).font(.caption).foregroundStyle(.secondary)
                    PermissionGuideView(theme: theme, onOpenSettings: {}, onConfirmGranted: {})
                        .frame(width: 500, height: 580)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .padding(20)
    }
    .frame(width: 560, height: 3200)
    .preferredColorScheme(.dark)
}
