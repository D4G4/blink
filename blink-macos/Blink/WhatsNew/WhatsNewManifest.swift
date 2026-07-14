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

    /// Items in this build. Display order = array order. Each item is tagged
    /// with the version it first shipped in; older items stop showing once
    /// `lastSeenVersion >= introducedIn`. Keep old items here as long as the
    /// oldest still-supported install might need to see them.
    static let items: [WhatsNewItem] = [
        WhatsNewItem(
            icon: "pause.circle",
            title: "Pause that resumes itself",
            body: "Need a breather from breaks? Pause Blink for an hour, until tomorrow, or while a chosen app is open — and it turns itself back on automatically when the time's up. No more forgetting you paused it.",
            introducedIn: "5.2.0",
            openAction: .preferences(tab: 0)
        ),
        WhatsNewItem(
            icon: "calendar",
            title: "Auto-pause for meetings",
            body: "Turn on calendar pausing and Blink quietly steps aside during meetings with a Zoom, Meet, or Teams link — then resumes the moment they end. Events without a link get a gentle \u{201C}pause?\u{201D} nudge you can tap or ignore. Your calendar is read only to spot meeting times; nothing leaves your Mac.",
            introducedIn: "5.2.0",
            openAction: .preferences(tab: 0)
        ),
        WhatsNewItem(
            icon: "sparkles",
            title: "Smart break suggestions",
            body: "Instead of always saying \u{201C}Look at something far away,\u{201D} Blink can pick a healthier action — drink water, stand up, breathe, step outside — based on time of day, how long you've been sitting, and whether you're coming out of focus.",
            introducedIn: "5.1.0",
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
    ///   - Return only items whose `introducedIn` is strictly greater than
    ///     `lastSeen` (semver compare, pre-release suffixes stripped). This
    ///     means: 5.0.0 → 5.1.0 surfaces the 5.1.0 item; 5.1.0 → 5.2.0 skips
    ///     it and only shows 5.2.0 items; 5.1.0-beta.5 → 5.1.0-beta.6 →
    ///     5.1.0 all collapse to 5.1.0 and the item shows at most once.
    @MainActor
    static func itemsToShowOnLaunch(
        defaults: UserDefaults = .standard,
        currentVersion: String = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "",
        candidateItems: [WhatsNewItem] = WhatsNewManifest.items
    ) -> [WhatsNewItem]? {
        guard !currentVersion.isEmpty else { return nil }

        let lastSeen = defaults.string(forKey: lastSeenVersionKey)
        defaults.set(currentVersion, forKey: lastSeenVersionKey)

        guard let lastSeen else { return nil }
        let newItems = candidateItems.filter { isVersion($0.introducedIn, greaterThan: lastSeen) }
        return newItems.isEmpty ? nil : newItems
    }

    /// Compare two version strings as (major, minor, patch), ignoring any
    /// pre-release suffix after `-` (e.g. "5.1.0-beta.6" → 5.1.0). Non-numeric
    /// or missing components default to 0, so malformed input fails closed
    /// (won't trigger spurious dialogs).
    static func isVersion(_ candidate: String, greaterThan baseline: String) -> Bool {
        parse(candidate) > parse(baseline)
    }

    private static func parse(_ v: String) -> (Int, Int, Int) {
        let base = v.split(separator: "-").first.map(String.init) ?? v
        let parts = base.split(separator: ".").compactMap { Int($0) }
        return (
            parts.count > 0 ? parts[0] : 0,
            parts.count > 1 ? parts[1] : 0,
            parts.count > 2 ? parts[2] : 0
        )
    }
}
