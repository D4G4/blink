import XCTest
import SwiftUI
@testable import Blink

final class WhatsNewSnapshotTests: SnapshotTestCase {
    @MainActor func testWhatsNewWithManifest() {
        for v in [
            ThemeVariant(name: "peach", theme: .peach, colorScheme: .light),
            ThemeVariant(name: "midnight", theme: .midnight, colorScheme: .dark),
        ] {
            assertSnapshot(
                of: WhatsNewView(
                    theme: v.theme,
                    version: "5.0.9",
                    items: WhatsNewManifest.items,
                    onDismiss: {},
                    onOpenAction: { _ in }
                ),
                named: "whats_new_\(v.snapshotName)",
                width: 520, height: 460,
                colorScheme: v.colorScheme
            )
        }
    }

    /// Covers the multi-item rendering path so a future release adding
    /// 3+ items doesn't regress silently. Synthetic items, not the
    /// current manifest.
    @MainActor func testWhatsNewMultipleItems() {
        let items: [WhatsNewItem] = [
            WhatsNewItem(icon: "sparkles", title: "Smart break suggestions",
                         body: "Context-aware break prompts.",
                         openAction: .preferences(tab: 0)),
            WhatsNewItem(icon: "brain", title: "Refined flow detection",
                         body: "Better recognition of deep work sessions."),
            WhatsNewItem(icon: "leaf.fill", title: "Touch grass nudge",
                         body: "Late-afternoon outdoor suggestions when daylight is still out."),
        ]
        assertSnapshot(
            of: WhatsNewView(
                theme: .peach,
                version: "5.1.0",
                items: items,
                onDismiss: {},
                onOpenAction: { _ in }
            ),
            named: "whats_new_multiple_items_peach_light",
            width: 520, height: 460,
            colorScheme: .light
        )
    }
}
