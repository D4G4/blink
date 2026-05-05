import SwiftUI

struct PermissionOnboardingView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "eye.circle")
                .font(.system(size: 48))
                .foregroundStyle(.blue)

            Text("Blink needs Accessibility access")
                .font(.headline)

            Text("This allows Blink to detect your typing and mouse patterns to intelligently time your break reminders. No keystrokes or content are ever recorded.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)

            Button("Open System Settings") {
                PermissionManager.requestAccessibility()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Text("Blink will work as a simple timer without this permission, but smart flow detection will be disabled.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)
        }
        .padding(32)
    }
}
