import XCTest
import SwiftUI
@testable import Blink

final class WhatsNewSnapshotTests: SnapshotTestCase {
    @MainActor func testWhatsNewWithManifest() {
        for v in [
            ThemeVariant(name: "peach", theme: .peach, colorScheme: .light),
            ThemeVariant(name: "midnight", theme: .midnight, colorScheme: .dark),
        ] {
            // ScrollView-backed view; needs NSHostingView-based capture.
            assertHostedSnapshot(
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
                         introducedIn: "5.1.0",
                         openAction: .preferences(tab: 0, scrollTo: nil)),
            WhatsNewItem(icon: "brain", title: "Refined flow detection",
                         body: "Better recognition of deep work sessions.",
                         introducedIn: "5.1.0"),
            WhatsNewItem(icon: "leaf.fill", title: "Touch grass nudge",
                         body: "Late-afternoon outdoor suggestions when daylight is still out.",
                         introducedIn: "5.1.0"),
        ]
        assertHostedSnapshot(
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

    /// Stale-user back-catalogue: visual confirmation of what a user who
    /// skipped 5.0.0 → 6.0.0 sees in the dialog. Mirrors the
    /// `testStaleUserSkippingMultipleReleasesSeesEverything` unit-test
    /// scenario. Captured in both themes because card density looks
    /// different in light vs dark.
    @MainActor func testWhatsNewStaleUserBackCatalogue() {
        let items: [WhatsNewItem] = [
            WhatsNewItem(icon: "sparkles", title: "Smart break suggestions",
                         body: "Context-aware break prompts.",
                         introducedIn: "5.1.0",
                         openAction: .preferences(tab: 0, scrollTo: nil)),
            WhatsNewItem(icon: "moon.stars", title: "Quiet hours",
                         body: "Auto-mute notifications overnight.",
                         introducedIn: "5.2.0"),
            WhatsNewItem(icon: "leaf.fill", title: "Touch grass nudge",
                         body: "Outdoor suggestions in daylight.",
                         introducedIn: "5.3.0"),
            WhatsNewItem(icon: "brain", title: "Flow detection v2",
                         body: "Rewritten signal scoring.",
                         introducedIn: "6.0.0"),
        ]
        for v in [
            ThemeVariant(name: "peach", theme: .peach, colorScheme: .light),
            ThemeVariant(name: "midnight", theme: .midnight, colorScheme: .dark),
        ] {
            assertHostedSnapshot(
                of: WhatsNewView(
                    theme: v.theme,
                    version: "6.0.0",
                    items: items,
                    onDismiss: {},
                    onOpenAction: { _ in }
                ),
                named: "whats_new_stale_back_catalogue_\(v.snapshotName)",
                width: 520, height: 460,
                colorScheme: v.colorScheme
            )
        }
    }

    /// Partial catch-up: user was on 5.1.0 and updates to 6.0.0, so they
    /// see 3 of the 4 items in the digest (the 5.1.0 one is filtered out
    /// because they've already seen it). Mirrors the
    /// `testPartiallyStaleUserSeesOnlyItemsNewerThanLastSeen` unit-test.
    @MainActor func testWhatsNewPartialCatchUp() {
        let items: [WhatsNewItem] = [
            WhatsNewItem(icon: "moon.stars", title: "Quiet hours",
                         body: "Auto-mute notifications overnight.",
                         introducedIn: "5.2.0"),
            WhatsNewItem(icon: "leaf.fill", title: "Touch grass nudge",
                         body: "Outdoor suggestions in daylight.",
                         introducedIn: "5.3.0"),
            WhatsNewItem(icon: "brain", title: "Flow detection v2",
                         body: "Rewritten signal scoring.",
                         introducedIn: "6.0.0"),
        ]
        assertHostedSnapshot(
            of: WhatsNewView(
                theme: .peach,
                version: "6.0.0",
                items: items,
                onDismiss: {},
                onOpenAction: { _ in }
            ),
            named: "whats_new_partial_catch_up_peach_light",
            width: 520, height: 460,
            colorScheme: .light
        )
    }

    /// Forces ScrollView overflow: 7 items in a 460pt window. Verifies the
    /// dialog stays the same fixed size (header + scroller + Got it button
    /// all visible) and content scrolls instead of clipping. Without the
    /// ScrollView this used to push the footer off the bottom of the frame.
    @MainActor func testWhatsNewOverflowingDigestScrolls() {
        let items: [WhatsNewItem] = (1...7).map { i in
            WhatsNewItem(
                icon: "sparkles",
                title: "Feature \(i)",
                body: "Body paragraph describing feature \(i) in a couple of lines so the row takes its natural height like a real entry.",
                introducedIn: "5.\(i).0"
            )
        }
        assertHostedSnapshot(
            of: WhatsNewView(
                theme: .peach,
                version: "6.0.0",
                items: items,
                onDismiss: {},
                onOpenAction: { _ in }
            ),
            named: "whats_new_overflow_scroll_peach_light",
            width: 520, height: 460,
            colorScheme: .light
        )
    }
}
