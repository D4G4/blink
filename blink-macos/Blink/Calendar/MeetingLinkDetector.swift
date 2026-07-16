import Foundation

/// A recognized video-meeting provider, inferred from a URL host.
enum MeetingProvider: String, Equatable {
    case zoom
    case googleMeet
    case teams
    case webex
    case generic

    /// Short label for toast copy ("Paused for your Zoom meeting").
    var displayName: String {
        switch self {
        case .zoom: return "Zoom"
        case .googleMeet: return "Google Meet"
        case .teams: return "Teams"
        case .webex: return "Webex"
        case .generic: return "video call"
        }
    }
}

/// A meeting link found on a calendar event.
struct DetectedMeetingLink: Equatable {
    let provider: MeetingProvider
    let url: URL
}

/// Pure scanner that recognizes video-meeting links in the free-text fields of
/// a calendar event (its URL, notes, and location). No EventKit dependency so
/// it stays trivially unit-testable.
enum MeetingLinkDetector {
    /// Host substrings mapped to a provider. Matched against a parsed URL host,
    /// so `zoom.us` matches `us05web.zoom.us` but NOT `zoominfo.com`.
    private static let hostRules: [(needle: String, provider: MeetingProvider)] = [
        ("zoom.us", .zoom),
        ("zoomgov.com", .zoom),
        ("meet.google.com", .googleMeet),
        ("teams.microsoft.com", .teams),
        ("teams.live.com", .teams),
        ("webex.com", .webex),
        ("whereby.com", .generic),
        ("meet.jit.si", .generic),
        ("chime.aws", .generic),
        ("gotomeeting.com", .generic),
    ]

    /// Scan the event's fields in priority order (structured URL, then notes,
    /// then location) and return the first recognizable meeting link.
    static func detect(urlString: String?, notes: String?, location: String?) -> DetectedMeetingLink? {
        for field in [urlString, notes, location] {
            guard let field, !field.isEmpty else { continue }
            if let hit = firstMatch(in: field) { return hit }
        }
        return nil
    }

    private static func firstMatch(in text: String) -> DetectedMeetingLink? {
        let lower = text.lowercased()
        // Fast reject: no known host substring anywhere → nothing to find.
        guard hostRules.contains(where: { lower.contains($0.needle) }) else { return nil }

        // Preferred path: let NSDataDetector parse real URLs, then match the
        // host against the rules (host match avoids substring false positives).
        if let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) {
            let range = NSRange(text.startIndex..., in: text)
            for match in detector.matches(in: text, options: [], range: range) {
                guard let url = match.url, let host = url.host?.lowercased() else { continue }
                if let rule = hostRules.first(where: { host.contains($0.needle) }) {
                    return DetectedMeetingLink(provider: rule.provider, url: url)
                }
            }
        }

        // Fallback: a scheme-less link (e.g. "zoom.us/j/123" pasted in notes)
        // that NSDataDetector didn't parse. Rebuild a URL from the token.
        for rule in hostRules where lower.contains(rule.needle) {
            if let url = looseURL(containing: rule.needle, in: text) {
                return DetectedMeetingLink(provider: rule.provider, url: url)
            }
        }
        return nil
    }

    /// Find the whitespace-delimited token containing `needle` and coerce it
    /// into a URL, prepending `https://` when no scheme is present.
    private static func looseURL(containing needle: String, in text: String) -> URL? {
        let separators = CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: "<>\"'"))
        for token in text.components(separatedBy: separators) where token.lowercased().contains(needle) {
            var s = token.trimmingCharacters(in: CharacterSet(charactersIn: "()[],.;"))
            if !s.lowercased().hasPrefix("http") { s = "https://" + s }
            if let url = URL(string: s), let host = url.host, host.lowercased().contains(needle) {
                return url
            }
        }
        return nil
    }
}
