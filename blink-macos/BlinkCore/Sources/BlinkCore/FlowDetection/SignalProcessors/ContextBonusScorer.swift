import Foundation

/// Scores a bonus based on whether the active app is a "creative" tool.
/// IDEs and editors get a flow bonus. Weight: 0.10
public struct ContextBonusScorer: Sendable {
    public enum AppCategory: Sendable {
        case creative   // IDEs, editors, design tools, terminals
        case neutral    // browsers, file managers
        case consumption // social media, email, chat
    }

    private static let bundleCategories: [String: AppCategory] = [
        // Creative
        "com.apple.dt.Xcode": .creative,
        "com.microsoft.VSCode": .creative,
        "com.todesktop.230313mzl4w4u92": .creative, // Cursor
        "dev.zed.Zed": .creative,
        "com.sublimetext.4": .creative,
        "com.jetbrains.intellij": .creative,
        "com.googlecode.iterm2": .creative,
        "com.apple.Terminal": .creative,
        "net.ia.iaWriter": .creative,
        "com.figma.Desktop": .creative,
        "com.bohemiancoding.sketch3": .creative,
        "com.adobe.Photoshop": .creative,
        "com.adobe.illustrator": .creative,
        // Consumption
        "com.tinyspeck.slackmacgap": .consumption,
        "com.apple.MobileSMS": .consumption,
        "com.apple.mail": .consumption,
        "com.microsoft.Outlook": .consumption,
        "ru.keepcoder.Telegram": .consumption,
        "com.atebits.Tweetie2": .consumption,
    ]

    public init() {}

    /// Returns a score: creative=1.0, neutral=0.5, consumption=0.2, unknown=0.5
    public func score(frontmostBundleID: String?) -> Double {
        guard let bundleID = frontmostBundleID else { return 0.5 }

        // Check exact match first
        if let category = Self.bundleCategories[bundleID] {
            return Self.categoryScore(category)
        }

        // Heuristic: JetBrains apps all start with com.jetbrains
        if bundleID.hasPrefix("com.jetbrains") { return 1.0 }

        // Browsers are neutral — could be docs or social media
        if bundleID.contains("browser") || bundleID.contains("chrome") ||
           bundleID.contains("safari") || bundleID.contains("firefox") {
            return 0.5
        }

        return 0.5 // unknown = neutral
    }

    private static func categoryScore(_ category: AppCategory) -> Double {
        switch category {
        case .creative: return 1.0
        case .neutral: return 0.5
        case .consumption: return 0.2
        }
    }
}
