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
            body: "Pause for an hour, until tomorrow, or while an app is open — Blink turns itself back on automatically.",
            introducedIn: "5.2.0",
            openAction: .preferences(tab: 0, scrollTo: SettingsAnchor.pause)
        ),
        WhatsNewItem(
            icon: "calendar",
            title: "Auto-pause for meetings",
            body: "Blink steps aside during meetings with a Zoom, Meet, or Teams link, then resumes when they end. Your calendar is read on-device only.",
            introducedIn: "5.2.0",
            openAction: .preferences(tab: 0, scrollTo: SettingsAnchor.calendar)
        ),
        WhatsNewItem(
            icon: "sparkles",
            title: "Smart break suggestions",
            body: "A healthier nudge than \u{201C}look far away\u{201D} — drink water, stand up, or breathe, matched to the moment.",
            introducedIn: "5.1.0",
            openAction: .preferences(tab: 0, scrollTo: nil)
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
    ///   - Return only items that `surfaces(_:lastSeen:current:)` accepts:
    ///     items strictly newer than `lastSeen` (semver, pre-release suffixes
    ///     stripped) — 5.0.0 → 5.1.0 surfaces the 5.1.0 item; 5.1.0 → 5.2.0
    ///     shows only 5.2.0 items — PLUS a beta→stable promotion of the same
    ///     x.y.z: a tester on 5.2.0-beta.N sees the 5.2.0 digest once when the
    ///     stable 5.2.0 ships, even though the betas already showed those
    ///     items. Beta→beta stays quiet, and the second stable launch does not
    ///     reshow.
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
        let newItems = candidateItems.filter {
            surfaces($0.introducedIn, lastSeen: lastSeen, current: currentVersion)
        }
        return newItems.isEmpty ? nil : newItems
    }

    /// Whether an item introduced in `introducedIn` should surface, given the
    /// version last seen and the one now running.
    ///
    /// 1. Base rule: the item is newer than what the user last saw.
    /// 2. Promotion rule: rolling from a pre-release to the STABLE build of the
    ///    same x.y.z surfaces that version's items once. A beta tester still
    ///    gets the "the release is out" digest even though the betas already
    ///    showed the same items. Fires at most once — after it shows, `lastSeen`
    ///    becomes the stable string, so the next stable launch no longer
    ///    qualifies (both non-pre-release → promotion false).
    static func surfaces(_ introducedIn: String, lastSeen: String, current: String) -> Bool {
        if isVersion(introducedIn, greaterThan: lastSeen) { return true }
        let promotedToStable = !current.contains("-") && lastSeen.contains("-")
        return promotedToStable
            && parse(current) == parse(lastSeen)
            && parse(introducedIn) == parse(current)
    }

    /// The items that shipped in a specific version (major.minor.patch match,
    /// pre-release suffix ignored). Used by the Settings "What's New" card to
    /// re-open the digest for the *current* build after launch has already
    /// consumed the one-shot window — `itemsToShowOnLaunch` returns nil once
    /// seen, but this always resolves the current version's items.
    static func itemsForVersion(
        _ version: String,
        candidateItems: [WhatsNewItem] = WhatsNewManifest.items
    ) -> [WhatsNewItem] {
        let target = parse(version)
        return candidateItems.filter { parse($0.introducedIn) == target }
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
