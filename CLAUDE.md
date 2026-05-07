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

- **Accessibility** (required): CGEventTap for keystroke/mouse monitoring. App won't start timers without it.
- Prompted after onboarding completes, never during.
- When running from Xcode, each rebuild creates a new binary — must re-grant Accessibility each time. Not an issue with archived builds.

## Homebrew Distribution

- Tap repo: `~/GitHub/D4G4/homebrew-blink` (`Casks/blink.rb`)
- The app is ad-hoc signed (no Developer ID) — no TeamIdentifier, CDHash changes every build
- The cask **must** have a `postflight` that runs `xattr -cr` on the installed app — this strips `com.apple.quarantine` so Gatekeeper doesn't block launch with "Apple could not verify"
- Don't remove the `xattr -cr` postflight — without it the app won't launch at all
- Accessibility permission (`AXIsProcessTrustedWithOptions`) works for ad-hoc signed apps only when quarantine is stripped first; removing the postflight breaks both launch and permission persistence
- Because the app is ad-hoc signed, the TCC grant is tied to the binary's CDHash — upgrading to a new version (new CDHash) may require re-granting Accessibility permission

## Git Setup

- Repo: `git@github.com:D4G4/blink.git` (private)
- Git config: uses `~/.gitconfig-d4g4` via conditional include for `~/GitHub/D4G4/`
- SSH key: `~/.ssh/id_ed25519_d4g4`
- SSH push may fail with pack corruption on large pushes — use HTTPS as fallback

## Important Patterns

- `AppState(preview: true)` — use in all SwiftUI previews to skip permission checks and monitoring
- `ThemeManager.shared` — singleton, persists via `@AppStorage`
- `BlinkTheme.named(id)` — safe lookup, falls back to `.peach`
- Overlay views use `let bg = theme.overlayBackground(for: colorScheme)` pattern — can't chain methods directly on the function call due to Swift type inference
- `onBackgroundText(for: colorScheme)` — use for text on theme gradients (Mono needs dark text on light bg)

## Don't

- Don't use `AXIsProcessTrustedWithOptions` with prompt flag if already granted — causes repeated system dialogs
- Don't use MediaRemote private framework — causes stderr noise and permission errors
- Don't set `selectedIndex = -1` as sentinel in SwiftUI `@State` — causes array out of bounds before `onAppear`
- Don't use `.ultraThickMaterial` for themed dialogs — it's translucent and washes out in light mode
- Don't add external dependencies — the project is zero-dependency by design
