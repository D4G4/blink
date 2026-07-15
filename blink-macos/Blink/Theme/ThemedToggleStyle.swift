import SwiftUI

struct ThemedToggleStyle: ToggleStyle {
    let theme: BlinkTheme
    @Environment(\.colorScheme) private var colorScheme

    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label

            Spacer()

            Capsule()
                .fill(configuration.isOn ? theme.accent(for: colorScheme) : Color.gray.opacity(0.3))
                .frame(width: 36, height: 21)
                .overlay(
                    Circle()
                        .fill(.white)
                        .frame(width: 17, height: 17)
                        .shadow(color: .black.opacity(0.15), radius: 1, y: 1)
                        .offset(x: configuration.isOn ? 7.5 : -7.5)
                        .animation(.easeInOut(duration: 0.15), value: configuration.isOn)
                )
                .onTapGesture {
                    configuration.isOn.toggle()
                }
        }
    }
}
