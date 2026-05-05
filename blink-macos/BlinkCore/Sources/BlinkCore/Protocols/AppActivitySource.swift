import Foundation

public struct AppSwitchEvent: Sendable {
    public let timestamp: TimeInterval
    public let appBundleID: String

    public init(timestamp: TimeInterval, appBundleID: String) {
        self.timestamp = timestamp
        self.appBundleID = appBundleID
    }
}

public protocol AppActivitySource: AnyObject {
    var onAppSwitch: ((AppSwitchEvent) -> Void)? { get set }
    var onWindowTitleChange: (() -> Void)? { get set }
    func startMonitoring()
    func stopMonitoring()
}
