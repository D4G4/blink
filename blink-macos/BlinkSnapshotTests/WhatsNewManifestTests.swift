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
        d.set("5.0.9", forKey: key)
        let result = WhatsNewManifest.itemsToShowOnLaunch(defaults: d, currentVersion: "5.0.9")
        XCTAssertNil(result)
    }

    @MainActor
    func testUpgradeReturnsItems() {
        let d = makeDefaults()
        d.set("5.0.8", forKey: key)
        let result = WhatsNewManifest.itemsToShowOnLaunch(defaults: d, currentVersion: "5.0.9")
        XCTAssertNotNil(result, "Upgrade from 5.0.8 → 5.0.9 should show the manifest")
        XCTAssertEqual(result?.count, WhatsNewManifest.items.count)
        XCTAssertEqual(d.string(forKey: key), "5.0.9", "Bookkeeping must update to current")
    }

    @MainActor
    func testUpgradeSecondLaunchDoesNotReshow() {
        let d = makeDefaults()
        d.set("5.0.8", forKey: key)
        _ = WhatsNewManifest.itemsToShowOnLaunch(defaults: d, currentVersion: "5.0.9")
        let secondCall = WhatsNewManifest.itemsToShowOnLaunch(defaults: d, currentVersion: "5.0.9")
        XCTAssertNil(secondCall, "Same version on second launch should not reshow")
    }

    @MainActor
    func testEmptyVersionReturnsNil() {
        let d = makeDefaults()
        let result = WhatsNewManifest.itemsToShowOnLaunch(defaults: d, currentVersion: "")
        XCTAssertNil(result)
        XCTAssertNil(d.string(forKey: key), "Must not seed when version unknown")
    }
}
