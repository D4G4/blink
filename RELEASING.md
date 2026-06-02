# Releasing Blink

The release pipeline is fully automated via GitHub Actions. The dev's job is to bump one number, push a tag, walk away. Everything else — build, sign, notarize, EdDSA sign, GitHub Release, appcast publish, website deploy, Homebrew cask bump — happens autonomously.

## TL;DR — to ship a new version

```bash
# 1. Edit blink-macos/project.yml: bump MARKETING_VERSION (e.g. 5.0.5 → 5.0.6)
# 2. Commit + push to main + tag + push tag:
git add blink-macos/project.yml
git commit -m "chore(macos): bump to 5.0.6"
git push origin main
git tag v5.0.6
git push origin v5.0.6
# 3. Watch at https://github.com/D4G4/blink/actions — done in ~5 min.
```

That's it. Don't touch any other version field. The CI handles the rest.

## Which versions exist, what they mean, and which you touch

Blink has TWO version fields, and they serve different purposes. Touching the wrong one is a recurring source of subtle bugs.

| Field | What it is | Where it lives | Who sets it | Used by Sparkle? |
|---|---|---|---|---|
| `MARKETING_VERSION` (= `CFBundleShortVersionString`) | **Human-readable marketing version.** What users see in the menu bar, About window, release notes. Semantic format like `5.0.6`. | `blink-macos/project.yml` | **You bump this manually per release.** | Display only — shown in the "Blink 5.0.6 is now available—you have 5.0.4" text. NOT used for the "is this newer?" decision. |
| `CURRENT_PROJECT_VERSION` (= `CFBundleVersion`) | **Machine-readable build number.** Strictly monotonic integer Sparkle uses to decide "is this update newer than what's installed?" | `blink-macos/project.yml` (placeholder `"1"`) — but **overridden at build time** | `scripts/build-release.sh` computes it from `git rev-list --count HEAD`. **Do not hardcode.** | YES — primary comparator. If two releases share the same value, Sparkle answers "you're up to date" regardless of MARKETING_VERSION. |

**Single rule to remember**: bump `MARKETING_VERSION` in `project.yml` per release. Do not touch `CURRENT_PROJECT_VERSION` — leave the `"1"` placeholder. The build script always overrides it with the right value.

## What the CI does for you, in order

When you push a `v*` tag, [.github/workflows/release.yml](.github/workflows/release.yml) fires and runs these 6 jobs:

1. **`windows (x64)` + `windows (arm64)`** (parallel, ~2 min each) — Builds the Windows `.exe` artifacts.
2. **`macos`** (~3-4 min) — Runs `scripts/build-release.sh` which:
   - Generates the Xcode project via `xcodegen`
   - Archives the macOS app with the auto-derived `CFBundleVersion`
   - Signs with Developer ID Application (cert imported from `MACOS_CERTIFICATE_BASE64` secret)
   - Creates the DMG with the themed background
   - Signs the DMG
   - Submits to Apple's notary service (`AC_NOTARY` keychain profile, set up from `AC_API_KEY_BASE64`/`AC_API_KEY_ID`/`AC_API_ISSUER_ID` secrets) — Apple's queue currently takes 1-5 min
   - Staples the notarization ticket
   - EdDSA-signs the DMG for Sparkle via `sign_update --ed-key-file` (key file decoded from `SPARKLE_PRIVATE_KEY` secret)
   - Writes the appcast `<item>` snippet to `build/appcast-item.xml` and uploads as an artifact
3. **`release`** (~30s) — Creates the GitHub Release with all built artifacts attached.
4. **`appcast`** (~30s, runs after `release`) — Downloads the appcast item artifact, splices it into `website/appcast.xml`, commits to `main` (via `RELEASE_PAT` to bypass branch protection), and runs `npx wrangler deploy` to publish the new feed to `blink20.net/appcast.xml`.
5. **`homebrew`** (~30s) — Bumps `D4G4/homebrew-blink/Casks/blink.rb` with the new version, SHA, and `auto_updates true` declaration. Uses `HOMEBREW_TAP_TOKEN` secret.

Total wall-clock: **~5 minutes** end-to-end from `git push origin v5.x.y`.

## Existing-user upgrade paths

| User installed via | How they get the new version |
|---|---|
| **Direct DMG (blink20.net, GitHub release)** | Sparkle's background check (every 24h, or ~15s after launch as of v5.0.5+) finds the new appcast entry → standard "Update Available" dialog → one-click install + relaunch. |
| **Homebrew tap (`brew install --cask d4g4/blink/blink`)** | Two paths, depending on user preference: (a) `brew upgrade --cask blink` ships the cask version; (b) Sparkle auto-updates them (cask declares `auto_updates true` so brew doesn't fight). |
| **Mac App Store** | N/A — we don't ship there (see `feedback_no_input_monitoring`). |

## Things that should NEVER be done

- Don't hardcode `CURRENT_PROJECT_VERSION` to a specific number in `project.yml` — see [feedback_sparkle_uses_cfbundleversion](https://blink20.net/...) for the bug it caused.
- Don't `git push --tags` (pushes ALL local tags — has caused pack-corruption errors before).
- Don't run the workflow without the dev being available — Apple's notary queue can occasionally take 15+ min; if something hangs past 30 min in macos step, check `xcrun notarytool history` locally first before cancelling.
- Don't commit the Sparkle private key file to the repo. Don't import it into the runner's keychain (see [feedback_ci_notarize_hang](https://blink20.net/...) — the keychain ACL prompt hangs CI).

## CI gotchas we learned the hard way (linked from memory)

1. **`actions/checkout` defaults to `fetch-depth: 1` (shallow)** — `git rev-list --count HEAD` returns 1 → CFBundleVersion=1 → Sparkle "up to date" bug. Fix: `with: fetch-depth: 0` on the macos checkout.
2. **`sign_update` reads from the macOS Keychain by default** — triggers an ACL prompt that hangs headless CI forever. Fix: pass the key file via `--ed-key-file`.
3. **GitHub Rulesets bypass list matches by role, not by token** — `github-actions[bot]` runs at "Write" level but isn't matched by the "Write" role bypass entry. Fix: use a fine-grained PAT (`RELEASE_PAT`) for the appcast push.

## Required GitHub repo secrets

If you ever need to rotate or re-add these:

| Secret | What it's for | How to regenerate |
|---|---|---|
| `MACOS_CERTIFICATE_BASE64` | Developer ID Application cert (.p12 base64) | Keychain Access → My Certificates → export → `base64 -i cert.p12 \| pbcopy` |
| `MACOS_CERTIFICATE_PASSWORD` | The .p12 export password | Whatever was set above |
| `MACOS_KEYCHAIN_PASSWORD` | Throwaway password for the temp CI keychain | Any strong random string |
| `AC_API_KEY_BASE64` | App Store Connect API key for notarytool (.p8 base64) | App Store Connect → Users & Access → Keys → download .p8 → `base64 -i AuthKey_*.p8 \| pbcopy` |
| `AC_API_KEY_ID` | The 10-char key ID | App Store Connect → Keys page |
| `AC_API_ISSUER_ID` | The issuer UUID | App Store Connect → Keys page |
| `SPARKLE_PRIVATE_KEY` | EdDSA private key for Sparkle DMG signing (base64) | **DO NOT regenerate without a plan** — every existing user has the matching public key baked into their app; rotating it permanently strands them. Export from your Keychain via `~/.local/sparkle-2.9.2/bin/generate_keys -x /tmp/sparkle.key && base64 -i /tmp/sparkle.key \| pbcopy && rm /tmp/sparkle.key` |
| `RELEASE_PAT` | Fine-grained PAT for pushing appcast updates past branch protection | https://github.com/settings/personal-access-tokens/new — scope to D4G4/blink, Contents: Read and write |
| `HOMEBREW_TAP_TOKEN` | PAT for pushing cask bumps to D4G4/homebrew-blink | Same kind of fine-grained PAT, scoped to homebrew-blink |
| `BLINKCORE_DEPLOY_KEY` | SSH deploy key for the private BlinkCore Swift package dep | GitHub Settings → SSH and GPG keys → generate, register as deploy key on D4G4/blink-core (read-only) |
| `CLOUDFLARE_API_TOKEN` | Token for `wrangler deploy` (Workers static assets) | Cloudflare → My Profile → API Tokens → "Edit Cloudflare Workers" template |

## If you need to ship from your Mac instead of CI

The local path still works if CI is broken for whatever reason. Same script:

```bash
cd /Users/dg/GitHub/D4G4/Blink/blink-macos
scripts/build-release.sh
```

Then manually:
1. `gh release create v5.x.y blink-macos/build/Blink.dmg --title "v5.x.y" --target main --generate-notes`
2. Paste the printed appcast `<item>` into `website/appcast.xml` (right after `<language>en</language>`)
3. `git add website/appcast.xml && git commit -m "chore(appcast): publish v5.x.y" && git push`
4. `cd .. && npx wrangler deploy`
5. Bump the homebrew cask manually (`~/GitHub/D4G4/homebrew-blink/Casks/blink.rb`: `version`, `sha256`)

The local path's CFBundleVersion derivation works correctly because your local clone has full git history.

## Sparkle update behaviour (what users see)

- **On launch** (from v5.0.5+): silent background check ~15s after `applicationDidFinishLaunching`. If update found → standard "Update Available" dialog. If not → nothing.
- **Every 24h while running**: scheduled background check, same dialog if update found.
- **User-initiated**: Settings → Check for Updates → standard dialog immediately, with "You're up to date!" if nothing newer.

When an update is offered, user picks one of:
- **Install Update** → download → EdDSA-verify signature → swap the .app → relaunch
- **Remind Me Later** → defer 24h
- **Skip This Version** → silence prompts for this specific version (next release still triggers normally)
