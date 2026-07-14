import Foundation

/// One feature/announcement entry shown in the "What's New" window on
/// first launch after an upgrade. Add an item to `WhatsNewManifest.items`
/// in the same release that ships the feature.
struct WhatsNewItem: Identifiable {
    let id = UUID()

    /// SF Symbol name for the leading icon.
    let icon: String

    /// Short headline — what changed.
    let title: String

    /// One short paragraph — why it matters or how to use it.
    let body: String

    /// Marketing version this item first shipped in, e.g. "5.1.0". Used by
    /// `WhatsNewManifest.itemsToShowOnLaunch` to only surface items the user
    /// hasn't already seen — items where `introducedIn > lastSeen`. Pre-release
    /// suffixes are stripped during comparison so the same item doesn't replay
    /// on every beta bump within the same x.y.z (e.g. 5.1.0-beta.5 → 5.1.0-beta.6
    /// → 5.1.0 all collapse to 5.1.0).
    let introducedIn: String

    /// Optional deep-link callback fired when the user taps the item's
    /// chevron. Use for "Open Settings" / "Try it now" entry points.
    /// nil → no chevron, item renders as static info only.
    var openAction: OpenAction? = nil

    enum OpenAction {
        /// Open Preferences and land on a tab (0=General, 1=Theme,
        /// 2=Flow, 3=About). `scrollTo` optionally scrolls to and briefly
        /// highlights a specific section within that tab (a `SettingsAnchor`
        /// id) so a deep-linked setting is actually discoverable, not just
        /// somewhere in a long scroll view.
        case preferences(tab: Int, scrollTo: String?)
    }
}

/// Stable anchor ids for deep-linking to a specific Settings section
/// (ScrollViewReader targets). Kept as plain strings so they can be shared
/// across What's New, the discoverability tips, and SettingsView without a
/// circular dependency.
enum SettingsAnchor {
    static let calendar = "calendar"
    static let pause = "pause"
}
