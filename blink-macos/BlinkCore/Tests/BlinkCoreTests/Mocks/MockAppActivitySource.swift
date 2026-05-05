import Foundation
@testable import BlinkCore

final class MockAppActivitySource: AppActivitySource {
    var onAppSwitch: ((AppSwitchEvent) -> Void)?
    var onWindowTitleChange: (() -> Void)?

    func startMonitoring() {}
    func stopMonitoring() {}

    func simulateAppSwitch(at timestamp: TimeInterval, bundleID: String = "com.test.app") {
        onAppSwitch?(AppSwitchEvent(timestamp: timestamp, appBundleID: bundleID))
    }

    func simulateTitleChange() {
        onWindowTitleChange?()
    }
}
