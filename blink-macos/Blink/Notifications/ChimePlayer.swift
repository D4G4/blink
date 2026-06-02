import AppKit

/// Plays a short chime when a break ends. Sources are either a bundled audio
/// file (Blink's own ding) or a macOS system sound looked up by name via
/// `NSSound(named:)` — sandbox-safe, zero bundle cost.
@MainActor
final class ChimePlayer {
    static let shared = ChimePlayer()

    struct Chime: Identifiable, Hashable {
        let id: String              // persisted key
        let displayName: String
        let isBundled: Bool         // true → look in main bundle; false → NSSound(named:)
        let bundledExtension: String?

        static let blinkDing = Chime(id: "blink_ding", displayName: "Blink Ding",   isBundled: true,  bundledExtension: "m4a")
        static let tink      = Chime(id: "Tink",       displayName: "Tink — subtle", isBundled: false, bundledExtension: nil)
        static let purr      = Chime(id: "Purr",       displayName: "Purr — soft",   isBundled: false, bundledExtension: nil)
        static let hero      = Chime(id: "Hero",       displayName: "Hero — warm",   isBundled: false, bundledExtension: nil)
        static let glass     = Chime(id: "Glass",      displayName: "Glass",         isBundled: false, bundledExtension: nil)
        static let ping      = Chime(id: "Ping",       displayName: "Ping",          isBundled: false, bundledExtension: nil)

        static let all: [Chime] = [.blinkDing, .tink, .purr, .hero, .glass, .ping]
    }

    static let defaultChimeID = Chime.blinkDing.id
    static let defaultVolume: Double = 0.7

    private init() {}

    func play(id: String, volume: Double) {
        let chime = Chime.all.first(where: { $0.id == id }) ?? .blinkDing
        play(chime, volume: volume)
    }

    func play(_ chime: Chime, volume: Double) {
        // NSSound is one-shot per instance — fresh load each call avoids the
        // "play() does nothing while already playing" edge case during preview.
        let sound: NSSound?
        if chime.isBundled {
            guard let url = Bundle.main.url(forResource: chime.id, withExtension: chime.bundledExtension ?? "m4a") else {
                Log.e("ChimePlayer: bundled sound missing — \(chime.id).\(chime.bundledExtension ?? "?")")
                return
            }
            sound = NSSound(contentsOf: url, byReference: true)
        } else {
            sound = NSSound(named: NSSound.Name(chime.id))
        }
        guard let sound else {
            Log.e("ChimePlayer: NSSound load failed for \(chime.id)")
            return
        }
        sound.volume = Float(max(0, min(1, volume)))
        sound.play()
    }
}
