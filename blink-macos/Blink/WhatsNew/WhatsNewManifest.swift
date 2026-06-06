import Foundation

/// The What's New payload baked into THIS build. Items here surface in
/// a one-shot window on the first launch after a user upgrades.
///
/// Editing for a new release:
/// 1. Replace `items` with the entries for what shipped.
/// 2. Bump MARKETING_VERSION in project.yml so the version-change
///    detector below has something to compare against.
/// 3. Add a screenshot/snapshot test for any new visual.
enum WhatsNewManifest {

    /// Items in this build. Display order = array order.
    static let items: [WhatsNewItem] = [
        WhatsNewItem(
            icon: "sparkles",
            title: "Smart break suggestions",
            body: "Instead of always saying \u{201C}Look at something far away,\u{201D} Blink can pick a healthier action — drink water, stand up, breathe, step outside — based on time of day, how long you've been sitting, and whether you're coming out of focus.",
            openAction: .preferences(tab: 0)
        ),
    ]

    /// UserDefaults key tracking the version whose What's New window the
    /// current install has already seen (or implicitly acknowledged via
    /// first-install bootstrapping).
    static let lastSeenVersionKey = "whatsNewLastSeenVersion"

    /// Returns the items to show on this launch, or nil if there's nothing
    /// to surface. Side effect: writes the current bundle version to
    /// UserDefaults so subsequent launches don't reshow.
    ///
    /// Logic:
    ///   - Brand-new install (no key set) → write current, return nil.
    ///     New users get onboarding instead of a What's New window.
    ///   - Same version as last seen → nothing changed, return nil.
    ///   - Different version → user upgraded → return items.
    ///   - Empty items array → return nil regardless (build with no notes).
    @MainActor
    static func itemsToShowOnLaunch(
        defaults: UserDefaults = .standard,
        currentVersion: String = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
    ) -> [WhatsNewItem]? {
        guard !currentVersion.isEmpty else { return nil }

        let lastSeen = defaults.string(forKey: lastSeenVersionKey)
        defaults.set(currentVersion, forKey: lastSeenVersionKey)

        guard let lastSeen else { return nil }
        guard lastSeen != currentVersion else { return nil }
        return items.isEmpty ? nil : items
    }
}
