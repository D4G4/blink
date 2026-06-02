# Blink — Smart 20-20-20 Eye Break Reminder

## Project Structure

Two-layer architecture designed for cross-platform portability:

- **BlinkCore/** — Pure Swift package. All flow detection, timer, scoring, and compliance logic. Zero AppKit/SwiftUI imports. Portable to Windows/Linux later.
- **Blink/** — macOS app target. SwiftUI views, CGEventTap input monitoring, MenuBarExtra, overlay windows, themes, onboarding.
- **project.yml** — XcodeGen spec. Run `xcodegen generate` after adding/removing files.

## Build & Run

```bash
cd /Users/dg/GitHub/D4G4/Blink
xcodegen generate                    # regenerate .xcodeproj after file changes
xcodebuild -project Blink.xcodeproj -scheme Blink -configuration Debug build
```

Or open in Xcode: `xed .` → Cmd+R

## Tests

```bash
cd BlinkCore && swift test
```

85 tests across 13 suites. All tests are in `BlinkCore/Tests/BlinkCoreTests/`. Tests cover:
- All 5 signal scorers (AppSwitch, KeystrokeRhythm, MouseBehavior, WindowStability, ContextBonus)
- FlowScoreCalculator, FlowStateMachine (hysteresis, idle, meetings)
- TimerStateMachine (countdown, flow extension, pause/resume)
- BreakComplianceTracker (taken, dismissed, delayed, ignored)
- AdaptiveTimingEngine (learning, clamping, persistence)
- Integration scenarios (agent workflow, idle flapping, deep flow)
- Edge cases (negative timer, rapid state changes, buffer overflow)

## Key Constants

All thresholds are named constants:

**AppState** (`Blink/AppState.swift`):
- `idleBreakThreshold` = 90s — zero input before timer resets
- `naturalPauseThreshold` = 6s — input gap to deliver pending break in flow
- `maxPauseWaitSeconds` = 300s — max wait for natural pause before giving up
- `scoreTickInterval` = 30s — how often flow score is recalculated
- `postBreakGraceSeconds` = 60s — ignore idle after break ends

**FlowStateMachine** (`BlinkCore/.../FlowStateMachine.swift`):
- Flow entry: score > 0.7 sustained 3+ min
- Flow exit: score < 0.4 sustained 2+ min
- Deep flow: 15+ min in flow
- Idle: 90s no input (matches AppState)

**TimerStateMachine** (`BlinkCore/.../TimerStateMachine.swift`):
- Normal: 20 min, Flow: 30 min, Deep flow: 40 min

## Themes

5 themes defined in `Blink/Theme/BlinkTheme.swift`: Peach, Midnight, Sage, Sand, Mono.

- Mono is the only theme with `invertInDarkMode: true` — background and text colors flip in dark mode
- Each theme has separate light/dark overlay colors
- Icon PNGs are in `Blink/Assets.xcassets/AppIcon-{Theme}.imageset/`
- Icons must be 1024x1024 with transparent corners (use the fix script if adding new ones)

## Icon Corner Fix

Original icon PNGs have opaque black corners. Run this to fix:
```bash
swift /tmp/fix_icons2.swift
```
The script crops 6% from each side, rounds corners at 16% radius, outputs 1024x1024 with alpha.

## Permissions

- **Input Monitoring** (required): CGEventTap for keystroke/mouse monitoring, gated by `CGPreflightListenEventAccess` / `CGRequestListenEventAccess`. App won't start timers without it.
- Prompted after onboarding completes, never during. `AppState.checkPermissionsAndStart` fires `CGRequestListenEventAccess()` which shows the system dialog; the in-app guide window is shown as a backstop.
- When running from Xcode, each rebuild creates a new binary — must re-grant Input Monitoring each time. Not an issue with archived builds.
- **Do NOT use Accessibility (`AXIsProcessTrusted`).** MAS guideline 2.4.5 forbids using Accessibility APIs for non-accessibility purposes; Blink was rejected for this in 2026-05 and migrated to Input Monitoring in v4.0.0.

## Homebrew Distribution

- Tap repo: `~/GitHub/D4G4/homebrew-blink` (`Casks/blink.rb`)
- The app is **Developer ID signed + notarized** (Team ID `6V6FZW3FFN`, hardened runtime). The DMG is also signed + notarized + stapled.
- No `xattr -cr` postflight needed — Gatekeeper trusts the notarized + stapled DMG and the .app inside it. (The cask had this postflight in the ad-hoc era pre-v4.0; it's been removed since 4.0.2.)
- Input Monitoring permission persists across versions because the binary's TeamIdentifier is stable.

## Auto-update (Sparkle)

- v5.0.0+ ships [Sparkle 2.x](https://sparkle-project.org/) for in-app auto-update. SPM dep in `project.yml`. Wrapper at `Blink/BlinkUpdater.swift` (instantiated in `BlinkApp` `applicationDidFinishLaunching` to start the scheduled-check loop).
- **EdDSA keypair lives in the developer's login Keychain** (item: `https://sparkle-project.org`). The matching public key is hard-coded in `Info.plist` as `SUPublicEDKey`. Lose the private key → no future updates can ever be signed for installed users. Keep iCloud Keychain sync on.
- The standalone Sparkle tarball (for `generate_keys` etc.) lives outside the repo at `~/.local/sparkle-2.9.2/` — never commit Sparkle binaries into Blink's public repo.
- Appcast lives at `website/appcast.xml` and is served from `https://blink20.net/appcast.xml`. Release script (`scripts/build-release.sh`) signs the DMG with `sign_update` and prints a ready-to-paste `<item>` block.
- Sparkle runs for everyone (DMG, Homebrew). Brew users get auto-updated by Sparkle; the brew cask version then lags until the next cask bump.
- `entitlements`: `com.apple.security.temporary-exception.mach-lookup.global-name` includes `com.blink20.app-spks` so Sparkle 2's Installer.xpc can be reached from the sandboxed parent app.

## Git Setup

- Repo: `git@github.com:D4G4/blink.git` (**PUBLIC** repo)
- Git config: uses `~/.gitconfig-d4g4` via conditional include for `~/GitHub/D4G4/`
- SSH key: `~/.ssh/id_ed25519_d4g4`
- SSH push may fail with pack corruption on large pushes — use HTTPS as fallback
- **BlinkCore is a PRIVATE repo** (`git@github-d4g4:D4G4/blink-core.git`). It is referenced in `project.yml` as a remote Swift package URL. NEVER change it to a local `path:` reference — that risks exposing private source code in the public Blink repo via git tracking or history. When BlinkCore changes are needed, edit them in `blink-macos/BlinkCore/` (nested git repo), commit and push to the BlinkCore remote, tag a new version, then update the `from:` version in `project.yml`. Never commit BlinkCore files to the Blink repo.

## Important Patterns

- `AppState(preview: true)` — use in all SwiftUI previews to skip permission checks and monitoring
- `ThemeManager.shared` — singleton, persists via `@AppStorage`
- `BlinkTheme.named(id)` — safe lookup, falls back to `.peach`
- Overlay views use `let bg = theme.overlayBackground(for: colorScheme)` pattern — can't chain methods directly on the function call due to Swift type inference
- `onBackgroundText(for: colorScheme)` — use for text on theme gradients (Mono needs dark text on light bg)

## Don't

- Don't use `AXIsProcessTrusted` / `AXIsProcessTrustedWithOptions` — Accessibility is the wrong TCC bucket for Blink's use case (MAS guideline 2.4.5). Use `CGPreflightListenEventAccess` and `CGRequestListenEventAccess` instead.
- Don't use MediaRemote private framework — causes stderr noise and permission errors
- Don't set `selectedIndex = -1` as sentinel in SwiftUI `@State` — causes array out of bounds before `onAppear`
- Don't use `.ultraThickMaterial` for themed dialogs — it's translucent and washes out in light mode
- Don't add external dependencies — the project is zero-dependency by design
- **Don't change BlinkCore's package reference in `project.yml` from `url:` to `path:`** — Blink is a PUBLIC repo, BlinkCore is PRIVATE. A `path:` reference can leak private source into public git history. Always use the remote URL with a version tag.
