import XCTest
@testable import Blink

final class WhatsNewManifestTests: XCTestCase {

    private let key = WhatsNewManifest.lastSeenVersionKey

    private func makeDefaults() -> UserDefaults {
        // Suite-scoped defaults so the test can wipe its own state without
        // touching the running app's UserDefaults.
        let suite = "WhatsNewManifestTests-\(UUID().uuidString)"
        let d = UserDefaults(suiteName: suite)!
        d.removePersistentDomain(forName: suite)
        return d
    }

    @MainActor
    func testFirstInstallReturnsNilAndSeedsVersion() {
        let d = makeDefaults()
        XCTAssertNil(d.string(forKey: key))

        let result = WhatsNewManifest.itemsToShowOnLaunch(defaults: d, currentVersion: "5.0.9")
        XCTAssertNil(result, "Brand-new installs should not see What's New")
        XCTAssertEqual(d.string(forKey: key), "5.0.9", "Current version must be seeded")
    }

    @MainActor
    func testSameVersionReturnsNil() {
        let d = makeDefaults()
        d.set("5.2.0", forKey: key)
        let result = WhatsNewManifest.itemsToShowOnLaunch(defaults: d, currentVersion: "5.2.0")
        XCTAssertNil(result)
    }

    @MainActor
    func testUpgradePastIntroducedInReturnsItems() {
        let d = makeDefaults()
        d.set("5.0.9", forKey: key)
        let result = WhatsNewManifest.itemsToShowOnLaunch(defaults: d, currentVersion: "5.1.0")
        XCTAssertNotNil(result, "Upgrade from 5.0.9 → 5.1.0 should surface the 5.1.0 manifest")
        XCTAssertEqual(result?.count, WhatsNewManifest.items.count)
        XCTAssertEqual(d.string(forKey: key), "5.1.0", "Bookkeeping must update to current")
    }

    @MainActor
    func testUpgradeSecondLaunchDoesNotReshow() {
        let d = makeDefaults()
        d.set("5.0.9", forKey: key)
        _ = WhatsNewManifest.itemsToShowOnLaunch(defaults: d, currentVersion: "5.2.0")
        let secondCall = WhatsNewManifest.itemsToShowOnLaunch(defaults: d, currentVersion: "5.2.0")
        XCTAssertNil(secondCall, "Same version on second launch should not reshow")
    }

    /// Regression for the beta train: 5.1.0-beta.5 → 5.1.0-beta.6 must not
    /// replay the same 5.1.0 item every bump.
    @MainActor
    func testBetaBumpWithinSameXYZDoesNotReshow() {
        let d = makeDefaults()
        d.set("5.2.0-beta.5", forKey: key)
        let result = WhatsNewManifest.itemsToShowOnLaunch(defaults: d, currentVersion: "5.2.0-beta.6")
        XCTAssertNil(result, "Beta-to-beta within the same x.y.z must not reshow")
    }

    /// Beta tester rolling over to the stable release of the same x.y.z
    /// shouldn't see the dialog again either.
    @MainActor
    func testBetaToStableSameXYZDoesNotReshow() {
        let d = makeDefaults()
        d.set("5.2.0-beta.6", forKey: key)
        let result = WhatsNewManifest.itemsToShowOnLaunch(defaults: d, currentVersion: "5.2.0")
        XCTAssertNil(result)
    }

    /// If a future release ships no items with a higher `introducedIn`,
    /// upgrading past that version must not pop an empty dialog.
    @MainActor
    func testUpgradePastManifestWithNoNewerItemsReturnsNil() {
        let d = makeDefaults()
        d.set("5.2.0", forKey: key)
        // The newest items in the current manifest are introducedIn = 5.2.0, so
        // a 5.2.0 → 5.3.0 jump finds nothing new.
        let result = WhatsNewManifest.itemsToShowOnLaunch(defaults: d, currentVersion: "5.3.0")
        XCTAssertNil(result)
    }

    @MainActor
    func testEmptyVersionReturnsNil() {
        let d = makeDefaults()
        let result = WhatsNewManifest.itemsToShowOnLaunch(defaults: d, currentVersion: "")
        XCTAssertNil(result)
        XCTAssertNil(d.string(forKey: key), "Must not seed when version unknown")
    }

    // MARK: - Stale-user / multi-release upgrade scenarios

    /// Synthetic manifest spanning four releases, used to test what a user
    /// who skipped several versions sees when they finally update.
    private func multiReleaseManifest() -> [WhatsNewItem] {
        [
            WhatsNewItem(icon: "sparkles", title: "Smart break suggestions",
                         body: "Context-aware break prompts.",
                         introducedIn: "5.1.0"),
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
    }

    /// Rip Van Winkle case: user hadn't updated since 5.0.0 and jumps
    /// straight to 6.0.0. They should see the full back-catalogue in one
    /// dialog, in manifest order.
    @MainActor
    func testStaleUserSkippingMultipleReleasesSeesEverything() {
        let d = makeDefaults()
        d.set("5.0.0", forKey: key)
        let result = WhatsNewManifest.itemsToShowOnLaunch(
            defaults: d,
            currentVersion: "6.0.0",
            candidateItems: multiReleaseManifest()
        )
        XCTAssertEqual(result?.count, 4, "All four post-5.0.0 items should surface")
        XCTAssertEqual(
            result?.map(\.introducedIn),
            ["5.1.0", "5.2.0", "5.3.0", "6.0.0"],
            "Order must match the manifest array (oldest → newest as authored)"
        )
        XCTAssertEqual(d.string(forKey: key), "6.0.0")
    }

    /// Partial catch-up: user on 5.1.0 (saw the first item already) jumps
    /// to 6.0.0. They should see the three NEW items but not the 5.1.0 one
    /// they've already seen.
    @MainActor
    func testPartiallyStaleUserSeesOnlyItemsNewerThanLastSeen() {
        let d = makeDefaults()
        d.set("5.1.0", forKey: key)
        let result = WhatsNewManifest.itemsToShowOnLaunch(
            defaults: d,
            currentVersion: "6.0.0",
            candidateItems: multiReleaseManifest()
        )
        XCTAssertEqual(result?.map(\.introducedIn), ["5.2.0", "5.3.0", "6.0.0"])
    }

    /// Editorial pruning: if we drop old items from the manifest array, a
    /// stale user never sees those features. This is the "we decided the
    /// 5.1.0 hint is no longer worth surfacing" case.
    @MainActor
    func testPrunedManifestDoesNotResurrectOldItemsForStaleUser() {
        let d = makeDefaults()
        d.set("4.9.0", forKey: key)
        // Manifest no longer includes the 5.1.0 / 5.2.0 items — we pruned them.
        let pruned = multiReleaseManifest().filter {
            WhatsNewManifest.isVersion($0.introducedIn, greaterThan: "5.2.0")
        }
        let result = WhatsNewManifest.itemsToShowOnLaunch(
            defaults: d,
            currentVersion: "6.0.0",
            candidateItems: pruned
        )
        XCTAssertEqual(result?.map(\.introducedIn), ["5.3.0", "6.0.0"],
                       "A pruned manifest only shows what's still listed")
    }

    /// A brand-new install on a much later release still skips What's New —
    /// onboarding is the right surface for first-run, not a 4-item digest.
    @MainActor
    func testFreshInstallOnLaterReleaseStillSkipsWhatsNew() {
        let d = makeDefaults()
        let result = WhatsNewManifest.itemsToShowOnLaunch(
            defaults: d,
            currentVersion: "6.0.0",
            candidateItems: multiReleaseManifest()
        )
        XCTAssertNil(result, "First install must not pop What's New regardless of how many manifest items exist")
        XCTAssertEqual(d.string(forKey: key), "6.0.0")
    }

    /// Stale user jumping across pre-release / stable boundaries should
    /// still see everything once. lastSeen = 4.9.0 → current = 6.0.0-beta.2
    /// should still surface the full back-catalogue.
    @MainActor
    func testStaleUserUpgradingIntoABetaSeesBackCatalogue() {
        let d = makeDefaults()
        d.set("4.9.0", forKey: key)
        let result = WhatsNewManifest.itemsToShowOnLaunch(
            defaults: d,
            currentVersion: "6.0.0-beta.2",
            candidateItems: multiReleaseManifest()
        )
        XCTAssertEqual(result?.count, 4)
    }

    /// Second launch of the catch-up release must not re-pop the digest.
    @MainActor
    func testStaleUserDoesNotSeeBackCatalogueAgainOnSecondLaunch() {
        let d = makeDefaults()
        d.set("5.0.0", forKey: key)
        _ = WhatsNewManifest.itemsToShowOnLaunch(
            defaults: d,
            currentVersion: "6.0.0",
            candidateItems: multiReleaseManifest()
        )
        let second = WhatsNewManifest.itemsToShowOnLaunch(
            defaults: d,
            currentVersion: "6.0.0",
            candidateItems: multiReleaseManifest()
        )
        XCTAssertNil(second, "Second launch on the same version must not reshow")
    }

    // MARK: - Semver compare

    func testVersionCompareStripsPreReleaseSuffix() {
        XCTAssertFalse(WhatsNewManifest.isVersion("5.1.0-beta.6", greaterThan: "5.1.0-beta.5"))
        XCTAssertFalse(WhatsNewManifest.isVersion("5.1.0", greaterThan: "5.1.0-beta.6"))
        XCTAssertFalse(WhatsNewManifest.isVersion("5.1.0-beta.1", greaterThan: "5.1.0"))
    }

    func testVersionCompareAcrossMajorMinorPatch() {
        XCTAssertTrue(WhatsNewManifest.isVersion("5.1.0", greaterThan: "5.0.9"))
        XCTAssertTrue(WhatsNewManifest.isVersion("5.2.0", greaterThan: "5.1.9"))
        XCTAssertTrue(WhatsNewManifest.isVersion("6.0.0", greaterThan: "5.9.9"))
        XCTAssertFalse(WhatsNewManifest.isVersion("5.1.0", greaterThan: "5.1.0"))
        XCTAssertFalse(WhatsNewManifest.isVersion("5.0.9", greaterThan: "5.1.0"))
    }
}
