import SwiftUI

#Preview("Onboarding — Light") {
    OnboardingView(themeManager: ThemeManager.shared, onComplete: {})
        .frame(width: 800, height: 600)
        .preferredColorScheme(.light)
}

#Preview("Onboarding — Dark") {
    OnboardingView(themeManager: ThemeManager.shared, isDarkMode: true, onComplete: {})
        .frame(width: 800, height: 600)
        .preferredColorScheme(.dark)
}
