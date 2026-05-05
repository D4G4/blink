import Foundation

/// Computes a composite flow score (0.0-1.0) from multiple input signals.
/// Updated every 30 seconds by the app's tick loop.
public final class FlowScoreCalculator {
    // Rolling buffers (timestamps in seconds since reference date)
    private var keystrokeTimestamps: [TimeInterval] = []
    private var mouseEvents: [MouseEvent] = []
    private var appSwitchTimestamps: [TimeInterval] = []
    private var titleChangeTimestamps: [TimeInterval] = []
    private var currentBundleID: String?

    // Scorers
    private let appSwitchScorer = AppSwitchScorer()
    private let keystrokeRhythmScorer = KeystrokeRhythmScorer()
    private let mouseBehaviorScorer = MouseBehaviorScorer()
    private let windowStabilityScorer = WindowStabilityScorer()
    private let contextBonusScorer = ContextBonusScorer()

    // Weights
    private static let weights: [(Double, String)] = [
        (0.35, "appSwitch"),
        (0.25, "keystroke"),
        (0.20, "mouse"),
        (0.10, "window"),
        (0.10, "context"),
    ]

    private static let maxBufferAge: TimeInterval = 600 // 10 minutes, prune older

    public init() {}

    // MARK: - Ingest events

    public func ingestKeystroke(_ event: KeystrokeEvent) {
        keystrokeTimestamps.append(event.timestamp)
    }

    public func ingestMouseEvent(_ event: MouseEvent) {
        mouseEvents.append(event)
    }

    public func recordAppSwitch(_ event: AppSwitchEvent) {
        appSwitchTimestamps.append(event.timestamp)
        currentBundleID = event.appBundleID
    }

    public func recordWindowTitleChange(at timestamp: TimeInterval) {
        titleChangeTimestamps.append(timestamp)
    }

    public func setCurrentApp(bundleID: String) {
        currentBundleID = bundleID
    }

    // MARK: - Compute score

    public func currentScore(now: TimeInterval) -> Double {
        pruneOldEvents(now: now)

        let keystrokeWindow: TimeInterval = 120
        let recentKeystrokeCount = keystrokeTimestamps.filter { $0 > now - keystrokeWindow }.count

        let appSwitchScore = appSwitchScorer.score(
            switchTimestamps: appSwitchTimestamps, now: now
        )
        let keystrokeScore = keystrokeRhythmScorer.score(
            keystrokeTimestamps: keystrokeTimestamps, now: now
        )
        let mouseScore = mouseBehaviorScorer.score(
            mouseEvents: mouseEvents, keystrokeCount: recentKeystrokeCount, now: now
        )
        let windowScore = windowStabilityScorer.score(
            titleChangeTimestamps: titleChangeTimestamps, now: now
        )
        let contextScore = contextBonusScorer.score(
            frontmostBundleID: currentBundleID
        )

        let scores = [appSwitchScore, keystrokeScore, mouseScore, windowScore, contextScore]
        let weightValues = Self.weights.map(\.0)

        return zip(weightValues, scores).map(*).reduce(0, +)
    }

    // MARK: - Maintenance

    public func reset() {
        keystrokeTimestamps.removeAll()
        mouseEvents.removeAll()
        appSwitchTimestamps.removeAll()
        titleChangeTimestamps.removeAll()
        currentBundleID = nil
    }

    private func pruneOldEvents(now: TimeInterval) {
        let cutoff = now - Self.maxBufferAge
        keystrokeTimestamps.removeAll { $0 < cutoff }
        mouseEvents.removeAll { $0.timestamp < cutoff }
        appSwitchTimestamps.removeAll { $0 < cutoff }
        titleChangeTimestamps.removeAll { $0 < cutoff }
    }
}
