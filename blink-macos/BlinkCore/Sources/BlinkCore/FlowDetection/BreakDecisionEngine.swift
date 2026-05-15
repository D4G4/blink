import Foundation

/// Decides whether to show a break overlay or extend the timer.
/// Called when the 20-minute timer fires — evaluates 20 minutes of collected signals.
///
/// This replaces the continuous flow state machine approach.
/// Instead of detecting flow early and extending the timer, we collect
/// signals for the full 20 minutes and make ONE decision at break time.
public final class BreakDecisionEngine {

    /// The decision: interrupt or extend?
    public enum Decision: Equatable, Sendable {
        /// User is doing focused work — extend timer, show gentle nudge
        case extend(minutes: Int, reason: String)
        /// User is casually browsing — show break overlay
        case showBreak
    }

    /// Raw signal window collected over the timer period
    public struct SignalWindow {
        public var keystrokeCount: Int = 0
        public var clickCount: Int = 0
        public var scrollCount: Int = 0
        public var appSwitchCount: Int = 0
        public var windowSeconds: TimeInterval = 0  // how long this window covers
        public var currentAppBundleID: String?

        // Density metrics (computed)
        public var keystrokesPerMinute: Double {
            guard windowSeconds > 0 else { return 0 }
            return Double(keystrokeCount) / (windowSeconds / 60.0)
        }

        public var clicksPerMinute: Double {
            guard windowSeconds > 0 else { return 0 }
            return Double(clickCount) / (windowSeconds / 60.0)
        }

        public var scrollsPerMinute: Double {
            guard windowSeconds > 0 else { return 0 }
            return Double(scrollCount) / (windowSeconds / 60.0)
        }

        public var appSwitchesPerMinute: Double {
            guard windowSeconds > 0 else { return 0 }
            return Double(appSwitchCount) / (windowSeconds / 60.0)
        }

        public init() {}
    }

    // Accumulated signals since last break/reset
    private var window = SignalWindow()
    private var windowStartTime: TimeInterval?
    private var extensionCount: Int = 0  // how many times we've extended (0, 1, 2 max)

    /// Sensitivity (0.4–0.9) — higher = more likely to extend
    public var sensitivity: Double = 0.7

    public init() {}

    // MARK: - Ingest signals

    public func recordKeystroke() {
        window.keystrokeCount += 1
    }

    public func recordClick() {
        window.clickCount += 1
    }

    public func recordScroll() {
        window.scrollCount += 1
    }

    public func recordAppSwitch(bundleID: String) {
        window.appSwitchCount += 1
        window.currentAppBundleID = bundleID
    }

    public func setCurrentApp(bundleID: String) {
        window.currentAppBundleID = bundleID
    }

    /// Call on each tick to update the window duration
    public func tick(now: TimeInterval) {
        if windowStartTime == nil {
            windowStartTime = now
        }
        window.windowSeconds = now - (windowStartTime ?? now)
    }

    // MARK: - Decide

    /// Called when the timer fires. Evaluates all collected signals.
    /// Returns whether to extend the timer or show a break.
    public func decide() -> Decision {
        let kpm = window.keystrokesPerMinute
        let cpm = window.clicksPerMinute
        let spm = window.scrollsPerMinute
        let switches = window.appSwitchesPerMinute
        let isCreativeApp = Self.isCreativeApp(window.currentAppBundleID)

        // How many extensions already used
        if extensionCount >= 2 {
            // Max 2 extensions (20 → 30 → 40 min). No more.
            return .showBreak
        }

        // Score the work intensity (0.0–1.0)
        let score = computeScore(
            kpm: kpm, cpm: cpm, spm: spm,
            switches: switches, isCreativeApp: isCreativeApp
        )

        // Threshold based on sensitivity
        // High sensitivity (0.9) → lower threshold (0.3) → easier to extend
        // Low sensitivity (0.4) → higher threshold (0.7) → harder to extend
        let threshold = 1.1 - sensitivity  // 0.4→0.7, 0.7→0.4, 0.9→0.2

        if score >= threshold {
            extensionCount += 1
            let extendTo = extensionCount == 1 ? 30 : 40
            let reason = describeScore(kpm: kpm, cpm: cpm, isCreativeApp: isCreativeApp)
            return .extend(minutes: extendTo, reason: reason)
        } else {
            return .showBreak
        }
    }

    // MARK: - Score computation

    /// Compute a work intensity score from 0.0 (idle/casual) to 1.0 (deep work)
    private func computeScore(
        kpm: Double, cpm: Double, spm: Double,
        switches: Double, isCreativeApp: Bool
    ) -> Double {
        var score = 0.0

        // Keyboard is the strongest signal (weight: 40%)
        // 0 kpm = 0, 30+ kpm = full score, 80+ kpm = bonus
        let keyboardScore: Double
        switch kpm {
        case 0: keyboardScore = 0
        case ..<10: keyboardScore = 0.2
        case ..<30: keyboardScore = 0.5
        case ..<80: keyboardScore = 0.8
        default: keyboardScore = 1.0
        }
        score += keyboardScore * 0.40

        // Clicks indicate engagement (weight: 20%)
        // Designers click a LOT (30+ cpm). Casual users click 2-5 cpm.
        let clickScore: Double
        switch cpm {
        case 0: clickScore = 0
        case ..<2: clickScore = 0.2
        case ..<5: clickScore = 0.4
        case ..<15: clickScore = 0.7
        default: clickScore = 1.0
        }
        score += clickScore * 0.20

        // Low app switching = focused (weight: 20%)
        // 0-1 switches/min = focused. 3+ = distracted.
        let switchScore: Double
        switch switches {
        case 0: switchScore = 1.0
        case ..<0.5: switchScore = 0.8
        case ..<1: switchScore = 0.5
        case ..<2: switchScore = 0.3
        default: switchScore = 0
        }
        score += switchScore * 0.20

        // Creative app bonus (weight: 10%)
        score += (isCreativeApp ? 1.0 : 0.3) * 0.10

        // Scroll-only penalty (weight: 10%)
        // High scroll + no keyboard = consumption, not creation
        let scrollOnlyScore: Double
        if kpm < 5 && spm > 5 {
            scrollOnlyScore = 0  // scrolling feed, no typing
        } else {
            scrollOnlyScore = 0.5
        }
        score += scrollOnlyScore * 0.10

        return min(score, 1.0)
    }

    private func describeScore(kpm: Double, cpm: Double, isCreativeApp: Bool) -> String {
        if kpm > 30 {
            return "Active typing detected"
        } else if cpm > 10 {
            return "High interaction detected"
        } else if isCreativeApp {
            return "Working in a creative app"
        } else {
            return "Sustained activity detected"
        }
    }

    // MARK: - App classification

    private static let creativeAppPrefixes: Set<String> = [
        "com.microsoft.VSCode",
        "com.apple.dt.Xcode",
        "dev.zed",
        "com.sublimetext",
        "com.jetbrains",
        "com.figma",
        "com.adobe.Photoshop",
        "com.adobe.Illustrator",
        "com.apple.FinalCut",
        "com.apple.Logic",
        "com.googlecode.iterm2",
        "com.apple.Terminal",
        "net.kovidgoyal.kitty",
        "com.github.wez.wezterm",
        "io.alacritty",
        "com.notion",
        "com.obsidian",
        "com.linear",
    ]

    static func isCreativeApp(_ bundleID: String?) -> Bool {
        guard let id = bundleID else { return false }
        return creativeAppPrefixes.contains { id.hasPrefix($0) }
    }

    // MARK: - Reset

    /// Reset after a break is taken or dismissed. Call when timer restarts.
    public func resetWindow() {
        window = SignalWindow()
        windowStartTime = nil
    }

    /// Full reset including extension count. Call on idle/walk-away.
    public func resetAll() {
        resetWindow()
        extensionCount = 0
    }

    /// Current window for debug/display
    public var currentWindow: SignalWindow { window }

    /// How many times we've extended
    public var currentExtensionCount: Int { extensionCount }
}
