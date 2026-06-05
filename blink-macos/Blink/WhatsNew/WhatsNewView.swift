import SwiftUI

/// The generic What's New layout: header, one card per `WhatsNewItem`,
/// dismiss button. Identical rendering for every release — only the
/// `items` array changes between builds.
struct WhatsNewView: View {
    let theme: BlinkTheme
    let version: String
    let items: [WhatsNewItem]
    let onDismiss: () -> Void
    let onOpenAction: (WhatsNewItem.OpenAction) -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let accent = theme.accent(for: colorScheme)
        VStack(spacing: 0) {
            header(accent: accent)

            VStack(alignment: .leading, spacing: 10) {
                ForEach(items) { item in
                    itemRow(item, accent: accent)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)

            Divider()
            footerBar(accent: accent)
        }
        .frame(width: 520, height: 460)
    }

    // MARK: - Pieces

    private func header(accent: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "gift.fill")
                .font(.system(size: 18))
                .foregroundStyle(accent)
            VStack(alignment: .leading, spacing: 1) {
                Text("What's new in Blink")
                    .font(.system(size: 17, weight: .semibold))
                Text("v\(version)")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(accent.opacity(0.08))
    }

    private func itemRow(_ item: WhatsNewItem, accent: Color) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(accent.opacity(0.14))
                    .frame(width: 42, height: 42)
                Image(systemName: item.icon)
                    .font(.system(size: 18))
                    .foregroundStyle(accent)
                    .symbolRenderingMode(.hierarchical)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(.system(size: 14, weight: .semibold))
                Text(item.body)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            if let action = item.openAction {
                Button {
                    onOpenAction(action)
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.secondary.opacity(0.06))
        )
    }

    private func footerBar(accent: Color) -> some View {
        HStack {
            Spacer()
            Button {
                onDismiss()
            } label: {
                Text("Got it")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 7)
                    .background(accent)
                    .clipShape(RoundedRectangle(cornerRadius: 7))
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.defaultAction)
        }
        .padding(14)
    }
}

#Preview("Peach light") {
    WhatsNewView(
        theme: .peach,
        version: "5.0.9",
        items: WhatsNewManifest.items,
        onDismiss: {},
        onOpenAction: { _ in }
    )
}

#Preview("Midnight dark") {
    WhatsNewView(
        theme: .midnight,
        version: "5.0.9",
        items: WhatsNewManifest.items,
        onDismiss: {},
        onOpenAction: { _ in }
    )
    .preferredColorScheme(.dark)
}
