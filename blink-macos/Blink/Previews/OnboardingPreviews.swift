import SwiftUI

#Preview("Onboarding") {
    OnboardingView(themeManager: ThemeManager.shared, onComplete: {})
        .frame(width: 800, height: 600)
        .preferredColorScheme(.light)
}
