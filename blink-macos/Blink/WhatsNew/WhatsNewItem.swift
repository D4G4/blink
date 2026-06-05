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

    /// Optional deep-link callback fired when the user taps the item's
    /// chevron. Use for "Open Settings" / "Try it now" entry points.
    /// nil → no chevron, item renders as static info only.
    var openAction: OpenAction? = nil

    enum OpenAction {
        /// Open Preferences and land on a tab (0=General, 1=Theme,
        /// 2=Flow, 3=About).
        case preferences(tab: Int)
    }
}
