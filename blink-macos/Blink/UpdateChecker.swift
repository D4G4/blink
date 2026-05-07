import Foundation
import os

private let log = Logger(subsystem: "com.blink.app", category: "Update")

/// Checks GitHub Releases for a newer version on launch.
@MainActor
final class UpdateChecker: ObservableObject {
    static let shared = UpdateChecker()

    @Published var updateAvailable: Bool = false
    @Published var latestVersion: String?
    @Published var downloadURL: URL?

    private static let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    private static let releasesURL = URL(string: "https://api.github.com/repos/D4G4/blink/releases/latest")!

    func checkForUpdate() {
        Task {
            do {
                var request = URLRequest(url: Self.releasesURL)
                request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
                request.timeoutInterval = 10

                let (data, _) = try await URLSession.shared.data(for: request)

                guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let tagName = json["tag_name"] as? String else { return }

                let latest = tagName.replacingOccurrences(of: "v", with: "")
                let current = Self.currentVersion

                if isNewer(latest, than: current) {
                    log.info("Update available: \(current) → \(latest)")
                    latestVersion = latest
                    updateAvailable = true

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
                    log.info("Up to date: \(current)")
                }
            } catch {
                log.debug("Update check failed: \(error.localizedDescription)")
            }
        }
    }

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
