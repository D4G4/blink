import SwiftUI

struct ThemedToggleStyle: ToggleStyle {
    let theme: BlinkTheme

    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label

            Spacer()

            Capsule()
                .fill(configuration.isOn ? theme.accent : Color.gray.opacity(0.3))
                .frame(width: 40, height: 24)
                .overlay(
                    Circle()
                        .fill(.white)
                        .frame(width: 20, height: 20)
                        .shadow(color: .black.opacity(0.15), radius: 1, y: 1)
                        .offset(x: configuration.isOn ? 8 : -8)
                        .animation(.easeInOut(duration: 0.15), value: configuration.isOn)
                )
                .onTapGesture {
                    configuration.isOn.toggle()
                }
        }
    }
}
