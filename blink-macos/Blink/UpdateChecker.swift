import AppKit

/// Checks GitHub Releases for a newer version on launch.
@MainActor
final class UpdateChecker: ObservableObject {
    static let shared = UpdateChecker()

    enum CheckResult: Equatable {
        case upToDate
        case available(String)
        case failed
    }

    @Published var updateAvailable: Bool = false
    @Published var latestVersion: String?
    @Published var downloadURL: URL?
    @Published var isChecking: Bool = false
    @Published var lastCheckResult: CheckResult?
    private static let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    private static let releasesURL = URL(string: "https://api.github.com/repos/D4G4/blink/releases/latest")!

    /// True when installed from the Mac App Store (has a receipt file).
    static let isAppStore: Bool = {
        Bundle.main.appStoreReceiptURL?.path().contains("sandboxReceipt") == true ||
        Bundle.main.appStoreReceiptURL.flatMap({ FileManager.default.fileExists(atPath: $0.path()) }) == true
    }()

    enum InstallSource {
        case appStore   // sandboxed install — update checks skipped entirely
        case homebrew   // installed via the D4G4/homebrew-blink cask
        case dmg        // direct download from a GitHub release
    }

    /// Best-effort install-source detection so the update HUD can offer
    /// the right upgrade path. Homebrew users get a `brew upgrade` command
    /// to copy; DMG users get a direct download link.
    ///
    /// Detection heuristic for Homebrew: check whether `Caskroom/blink/`
    /// contains a versioned subdirectory (e.g. `1.4.0/`) under either
    /// standard prefix (`/opt/homebrew` for Apple Silicon, `/usr/local`
    /// for Intel). Checking only for the parent dir's existence
    /// mis-detects users who once installed via brew and later uninstalled
    /// — brew sometimes leaves an empty `Caskroom/blink/` behind. A
    /// non-empty subdirectory listing is the reliable signal that brew
    /// currently tracks an install.
    static let installSource: InstallSource = {
        if isAppStore { return .appStore }
        let fm = FileManager.default
        for cask in ["/opt/homebrew/Caskroom/blink", "/usr/local/Caskroom/blink"] {
            if let contents = try? fm.contentsOfDirectory(atPath: cask),
               !contents.filter({ !$0.hasPrefix(".") }).isEmpty {
                return .homebrew
            }
        }
        return .dmg
    }()

    private var periodicTimer: Timer?

    func startPeriodicChecks() {
        guard !Self.isAppStore else {
            Log.i("App Store install — skipping update checks")
            return
        }
        checkForUpdate()
        periodicTimer = Timer.scheduledTimer(withTimeInterval: 86400, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.checkForUpdate()
            }
        }
    }

    func checkForUpdate() {
        isChecking = true
        lastCheckResult = nil
        Task {
            do {
                var request = URLRequest(url: Self.releasesURL)
                request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
                request.timeoutInterval = 10

                let (data, _) = try await URLSession.shared.data(for: request)

                guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let tagName = json["tag_name"] as? String else {
                    isChecking = false
                    lastCheckResult = .failed
                    return
                }

                let latest = tagName.replacingOccurrences(of: "v", with: "")
                let current = Self.currentVersion

                if isNewer(latest, than: current) {
                    Log.i("Update available: \(current) → \(latest)")
                    latestVersion = latest
                    updateAvailable = true
                    lastCheckResult = .available(latest)

                    // Find DMG download URL from assets
                    if let assets = json["assets"] as? [[String: Any]] {
                        for asset in assets {
                            if let name = asset["name"] as? String, name.hasSuffix(".dmg"),
                               let url = asset["browser_download_url"] as? String {
                                downloadURL = URL(string: url)
                                break
                            }
                        }
                    }

                    // Fallback to release page
                    if downloadURL == nil, let htmlURL = json["html_url"] as? String {
                        downloadURL = URL(string: htmlURL)
                    }
                } else {
                    Log.i("Up to date: \(current)")
                    lastCheckResult = .upToDate
                }
            } catch {
                Log.d("Update check failed: \(error.localizedDescription)")
                lastCheckResult = .failed
            }
            isChecking = false
        }
    }

    static let brewCommand = "brew update && brew upgrade --cask blink"

    /// Simple semver comparison: "1.2.0" > "1.1.0"
    private func isNewer(_ a: String, than b: String) -> Bool {
        let aParts = a.split(separator: ".").compactMap { Int($0) }
        let bParts = b.split(separator: ".").compactMap { Int($0) }

        for i in 0..<max(aParts.count, bParts.count) {
            let av = i < aParts.count ? aParts[i] : 0
            let bv = i < bParts.count ? bParts[i] : 0
            if av > bv { return true }
            if av < bv { return false }
        }
        return false
    }
}
