# Acknowledgments

Blink bundles third-party assets credited below.

## Audio

### Break-end chime — `blink-macos/Blink/Sounds/blink_ding.m4a`

- **Title**: Ding
- **Author**: [Aiwha](https://freesound.org/people/Aiwha/)
- **Source**: <https://freesound.org/people/Aiwha/sounds/196106/>
- **License**: [Creative Commons Attribution 4.0 International (CC BY 4.0)](https://creativecommons.org/licenses/by/4.0/)
- **Modifications**: Re-encoded from 24-bit/48 kHz WAV (535 KB) to AAC inside `.m4a` at 96 kbps (~19 KB) for smaller bundle size. No audio editing.
- **Provenance**: Distributed in Apple's [Scrumdinger](https://developer.apple.com/tutorials/app-dev-training/getting-started-with-scrumdinger) SwiftUI tutorial sample app as `Resources/ding.wav`.

The macOS system sounds (Tink, Purr, Hero, Glass, Ping) exposed in the chime
picker are not bundled — Blink looks them up at runtime via `NSSound(named:)`
and they remain Apple's property under standard macOS licensing.
