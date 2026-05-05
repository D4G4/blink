import Foundation
import Testing
@testable import BlinkCore

@Suite("ContextBonusScorer")
struct ContextBonusScorerTests {
    let scorer = ContextBonusScorer()

    @Test("Creative app = max score")
    func creativeApp() {
        #expect(scorer.score(frontmostBundleID: "com.apple.dt.Xcode") == 1.0)
        #expect(scorer.score(frontmostBundleID: "com.microsoft.VSCode") == 1.0)
        #expect(scorer.score(frontmostBundleID: "com.googlecode.iterm2") == 1.0)
    }

    @Test("Consumption app = low score")
    func consumptionApp() {
        #expect(scorer.score(frontmostBundleID: "com.tinyspeck.slackmacgap") == 0.2)
        #expect(scorer.score(frontmostBundleID: "com.apple.mail") == 0.2)
    }

    @Test("Unknown app = neutral")
    func unknownApp() {
        #expect(scorer.score(frontmostBundleID: "com.random.app") == 0.5)
    }

    @Test("Nil bundle ID = neutral")
    func nilBundleID() {
        #expect(scorer.score(frontmostBundleID: nil) == 0.5)
    }

    @Test("JetBrains apps = creative")
    func jetBrains() {
        #expect(scorer.score(frontmostBundleID: "com.jetbrains.pycharm") == 1.0)
        #expect(scorer.score(frontmostBundleID: "com.jetbrains.goland") == 1.0)
    }
}
