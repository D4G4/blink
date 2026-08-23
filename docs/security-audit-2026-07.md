# Blink — Security &amp; Privacy Audit (July 2026)

- **Scope:** the macOS app (`blink-macos/Blink/`) and the private `BlinkCore` engine.
- **Version audited:** `5.2.0-beta.20` (line numbers may drift; re-check before fixing).
- **Method:** 8 security dimensions, each finding independently re-verified by an
  adversarial refute-lens and an impact-lens, plus a completeness critic. Refuted
  claims were dropped; severities reflect the adversarial calibration.
- **Motivation:** some users are uncomfortable that Blink uses the Input
  Monitoring permission. This audit stress-tests whether that discomfort is
  warranted and hardens the app so the answer is a defensible "no".

---

## Bottom line

**Blink is not a keylogger, and it cannot quietly become one without a code
rewrite.** The capture boundary is clean by construction, not merely by policy:

- The single `CGEventTap` is `.listenOnly`; the `keyDown` branch touches no event
  field and emits a **timestamp-only** `KeystrokeEvent`.
- The `KeystrokeEvent` type has **no field capable of holding a keycode or
  character** — adding keystroke capture would require changing the type layer,
  not flipping a flag.
- Only four booleans (mic / camera / focus / media active) ever cross into
  `BlinkCore`, which performs **zero** disk, network, or `UserDefaults` I/O.
- Nothing derived from keyboard or mouse input ever leaves the Mac.

**Every real finding is a local metadata / honesty gap, not an exfiltration
channel.** The recurring theme: the app writes more to its own local logs and
preferences than its privacy copy admits. Calendar meeting **titles** and a
second-by-second **app-usage timeline** land in Blink's diagnostic logs, while
the Calendar permission prompt says "never recorded" and `PRIVACY.md` makes three
false claims. Redacting the logs and correcting the docs closes the exact trust
gap that makes users nervous.

### Severity summary

| Severity | Count |
| --- | --- |
| High | 2 |
| Medium | 5 |
| Low | 13 |
| Info | 8 |
| Verified clean (positive assurances) | 10 |

---

## Verified clean

What an audit of a keystroke-monitoring app is supposed to check — and what Blink
actually does. These hold up to source review; cite them to reassure users.

| Area | Finding |
| --- | --- |
| Not a keylogger, structurally | The one `CGEventTap` is `.listenOnly`; the `keyDown` branch reads no event field and emits a timestamp only. No `keycode`, `characters`, or unicode reads anywhere in the app or `BlinkCore`. |
| No window titles / screen capture | No Accessibility API is used at all — and a sandboxed app without it cannot read other apps' window titles. No screen-capture APIs. Only Blink's own window titles appear in code. |
| `BlinkCore` is inert | The engine does zero disk / network / `UserDefaults` I/O. Only four booleans cross into it — no raw input, no timing series, no identity. |
| Microphone = state check only | Reads a CoreAudio "is any device running" boolean, gated on permission. Never opens a stream or reads audio buffers. The "no audio recorded" usage string is truthful. |
| Meeting URLs never auto-opened | Attacker-controlled calendar text is parsed only to pick a provider label; the URL is never handed to `NSWorkspace.open`. No custom URL scheme or deep-link handler exists. |
| One network destination | Sparkle's HTTPS appcast only, with EdDSA-pinned payloads. No telemetry, no analytics SDK, no ATS relaxation, no system-profile transmission. |
| Minimal, honest entitlements | Verified against the shipped binary. Hardened runtime + Library Validation on; none of the injection-weakening keys. Sparkle's two XPC names are exact, not wildcards. |
| No secrets, pinned dependencies | Nothing sensitive in the working tree or full git history (pickaxe-scanned). `BlinkCore` and Sparkle pinned to exact revisions in a committed `Package.resolved`. |
| Correct permission bucket | Uses Input Monitoring, not Accessibility — the App Store–compliant choice (MAS 2.4.5). The probe tap in the permission flow is disabled the line after creation. |
| Notifications leak nothing | Break banners are compile-time constant text. No app name, meeting title, or timing context reaches the lock screen. |

---

## Findings

### High

Local-only (no data leaves the Mac), but each directly contradicts a promise the
user relied on when granting a permission. For a privacy-marketed app, this is
the trust-critical tier.

#### H1 — Calendar meeting titles are recorded to local logs, the unified system log, and preferences

- **Category:** privacy / claim-mismatch (local only)
- **Location:** `Blink/AppState.swift:1566, 1590, 1612` · `Blink/BlinkLog.swift:139` · `persistPauseMode()` `Blink/AppState.swift:1438`
- **What:** Every calendar-evaluation cycle logs the raw `meeting.title`
  (re-logged every 30 s while an event is in the look-ahead window). It reaches
  three plaintext sinks: the on-disk session log
  (`~/Library/Application Support/Blink/Logs/`, 7-day retention), the macOS
  unified log via an explicit `privacy: .public` override (Console.app +
  sysdiagnose), and the preferences plist via the `Codable` pause state.
- **Impact:** Titles like "1:1 re: layoffs", "Therapy", or "Interview at …" sit
  in plaintext where any local process/admin can read them, get captured into
  sysdiagnose sent to Apple, and are exactly what a user opens via
  *Settings → Debug → Open Log Files* to paste into a bug report. The Calendar
  prompt promised: "Event details stay on your Mac and are **never recorded**."
- **Fix:** Log the opaque `occurrenceKey` / a hash plus decision metadata
  (start/end/declined/provider) — never the title; the decision trail needs no
  title. Flip `BlinkLogger` interpolation to `privacy: .private`. Persist only
  `eventKey` + `until` in `PauseMode`; re-resolve the label from EventKit on
  restore.

#### H2 — PRIVACY.md is factually wrong on three counts

- **Category:** trust-doc / claim-mismatch
- **Location:** `PRIVACY.md:9, 23`
- **What:**
  1. States Blink **does not access your calendar** — it requests **Full
     Calendar Access** and reads titles / notes / location.
  2. Promises **30-day auto-deletion** — `pruneOldRecords()` is dead code, never
     called, so break history accumulates forever.
  3. Names `api.github.com` as the update endpoint — updates go through Sparkle
     to `blink20.net`.
- **Impact:** The one document a privacy-conscious user reads to decide whether
  to trust the app is wrong in the user-protective direction on all three points.
- **Fix:** Rewrite to match reality: disclose opt-in read-only calendar access
  and the fields read, the local `Logs/` directory and its 7-day retention, the
  real Sparkle endpoint, and either wire up `pruneOldRecords()` or drop the
  deletion claim.

### Medium

#### M1 — App-usage timeline + input-rate counts in plaintext logs

- **Category:** privacy (local only)
- **Location:** `Blink/AppState.swift:865, 1071` · `Blink/Permissions/InputMonitoringRationaleView.swift:74`
- **What:** One log line per app switch (bundle ID + timestamp; ~72 entries in a
  few hours observed) plus keystroke/click/scroll counts per 30 s, retained
  7 days, not gated by build config. Meanwhile the Input Monitoring rationale
  screen tells the user there is "no storage."
- **Impact:** A surveillance-grade record of work patterns and app usage that no
  UI discloses, in a support-shareable file. Contradicts the on-screen "no
  storage" assurance.
- **Fix:** Move per-switch app logging behind an opt-in diagnostic mode (off by
  default), or log app *category* not bundle IDs; correct the rationale copy.

#### M2 — Every os_log call forces `privacy: .public`, defeating default redaction

- **Category:** logging
- **Location:** `Blink/BlinkLog.swift:139`
- **What:** The central logger interpolates all dynamic values as `.public`. This
  is the mechanism that un-redacts meeting titles and bundle IDs (H1, M1) into
  Console.app and sysdiagnose, where os_log would otherwise mark them
  `<private>`.
- **Fix:** Default dynamic interpolation to private; keep `.public` only for
  static phrases. This one change caps the blast radius of every other logging
  finding.

#### M3 — install.sh (curl | bash) installs with zero verification and bypasses Gatekeeper

- **Category:** supply-chain
- **Location:** `install.sh:37`
- **What:** Downloads the release DMG and `cp -R`s it to `/Applications` with no
  `codesign` / `spctl` / checksum / Team-ID check. Because `curl` sets no
  quarantine xattr, Gatekeeper never assesses the app — the entire notarization
  trust story is skipped on this path.
- **Impact:** A substituted GitHub release asset (or TLS-stripping proxy) yields
  unverified code execution. Note: the website download path **is** quarantined
  and safe — only the README's curl installer is affected.
- **Fix:** `codesign --verify --strict` + assert `TeamIdentifier=6V6FZW3FFN` +
  `spctl --assess --type execute` (or re-attach quarantine) before launch.
  `build-release.sh` already computes a DMG SHA-256 — publish and verify it.

#### M4 — Break-history retention is unbounded (prune is dead code)

- **Category:** retention (local only)
- **Location:** `Blink/Persistence/PersistenceManager.swift:46`
- **What:** `pruneOldRecords(olderThan: 30)` exists but is never called, so daily
  break-compliance JSON accumulates forever — a permanent, growing work-schedule
  fingerprint (and the reason H2's "30-day deletion" claim is false).
- **Fix:** Call `persistence.pruneOldRecords()` at launch next to the existing
  `BlinkLog.pruneOldLogs()` (`AppState.swift:306`); add a regression test.

#### M5 — Release pipeline runs unpinned third-party code with write credentials

- **Category:** supply-chain
- **Location:** `.github/workflows/release.yml:316`
- **What:** `npx wrangler` (unpinned) and mutable-tag GitHub Actions execute with
  `CLOUDFLARE_API_TOKEN` / `RELEASE_PAT` in scope — the exact credentials that
  publish the appcast and website. An upstream or tag-repoint compromise could
  tamper the update channel.
- **Fix:** Pin wrangler to an exact version, pin every action to a full commit
  SHA, and scope the credentialed steps as narrowly as possible.

### Low

Hardening and correctness items — worth a cleanup pass, none exploitable on their
own.

| ID | Finding | Location | Fix |
| --- | --- | --- | --- |
| L1 | No update rollback protection: a feed/CDN compromise could force a silent auto-downgrade to any older *signed* build (payloads stay EdDSA-authentic). | `website/appcast.xml` · `BlinkUpdater` | Enforce `minimumAutoupdateVersion`, bump it on security releases. |
| L2 | Feed URL overridable via `UserDefaults` `SUFeedURL`; app never clears it and doesn't force `SUSendProfileInfo=false`. | `BlinkUpdater` | `clearFeedURLFromUserDefaults()` at startup; set the profile flag explicitly. |
| L3 | Pause state persists the meeting title &amp; frontmost-app identity to the prefs plist. | `Blink/PauseMode.swift:25` | Persist only `until` + `eventKey`; re-derive the label on restore. |
| L4 | Gabor vision-training history (health-adjacent) stored forever, no prune, no delete control. | `Blink/GaborExercise/GaborSessionStore.swift:33` | Retention cap + an explicit "Delete exercise history" control + disclosure. |
| L5 | Audio device names (often embed the owner's real name) logged on mic activation. | `Blink/Platform/MacContextDetector.swift:96` | Log the numeric device ID + flags, not the name. |
| L6 | `network.client` grants arbitrary outbound to a process also holding Input Monitoring + mic + calendar. | `Blink/Blink.entitlements:9` | Consider routing Sparkle through its own XPC downloader and dropping the app-level entitlement. |
| L7 | A shared calendar invite can silently suppress break reminders (auto-pause, toast suppressed while away). | `Blink/AppState.swift:1589` | Only auto-pause for accepted/organized events; cap the duration. |
| L8 | Meeting-link parser uses substring host matching + no scheme allowlist (latent — URL never opened today). | `Blink/Calendar/MeetingLinkDetector.swift:69` | Domain-boundary host match + `http/https` allowlist, before any open-URL feature exists. |
| L9 | Pre-migration `BlinkCore` source is retrievable from the public repo's git history. | git history | Treat v1 code as public; keep the `url:`-only rule + `BlinkCore/` gitignore for all post-2.x source. |
| L10 | CI disables SSH host-key verification (`StrictHostKeyChecking no`); BlinkCore test clone at unpinned HEAD. | `.github/workflows/release.yml:83` | Static `known_hosts` + clone the `Package.resolved`-pinned tag. |
| L11 | Homebrew cask SHA-256 computed by re-downloading the release asset instead of hashing the build artifact. | `.github/workflows/release.yml:338` | Carry the build-time SHA as a CI artifact into the cask job. |
| L12 | `maxWallClockMinutes` and `flowSensitivity` read from `UserDefaults` unclamped — same-user malware could disable the break backstop. | `Blink/AppState.swift:318` | Clamp on read. |
| L13 | Dead "Base interval" setting — the 10–45 min slider writes `@AppStorage("baseInterval")` that nothing reads; interval is hard-coded to 20 min. | `Blink/Settings/SettingsView.swift:488` | Wire the value through, or remove the control. |

### Info

Hygiene, dead code, and positive-but-worth-noting observations.

| ID | Finding | Location | Fix |
| --- | --- | --- | --- |
| I1 | Log/data files written world-readable (0644); protection relies on parent-directory modes. | `Blink/LifecycleLogger.swift:90` | Create sensitive files `0600`. |
| I2 | Log pruning only runs at launch; the live session file is unbounded. | `Blink/BlinkLog.swift:106` | Prune on a daily timer (the midnight-reset branch is a natural hook). |
| I3 | Focus-mode detection attempts a cross-app read of `com.apple.controlcenter` prefs the sandbox denies — dead code. | `Blink/Platform/MacContextDetector.swift:219` | Delete it or use a supported signal. |
| I4 | One `Process()` exec exists — a benign self-relaunch in the debug "Restart Onboarding" button. | `Blink/Settings/SettingsView.swift:869` | Optionally use `NSWorkspace.openApplication`. |
| I5 | Overlay adds a screen-parameters observer per break and never removes it (weak capture → no crash/leak of data; memory/CPU hygiene only). | `Blink/Notifications/OverlayWindow.swift:577` | Store and remove the token. |
| I6 | Sparkle release-notes HTML is attacker-controllable on a feed compromise (social-engineering only; JavaScript is verified disabled in the pinned Sparkle). | `website/appcast.xml` | Complements L1; addressed by feed integrity. |
| I7 | Dev preview server binds all interfaces (not shipped). | `serve.py:22` | Bind `127.0.0.1` instead of `0.0.0.0`. |
| I8 | PRIVACY.md overstates capture ("pauses between keystrokes") — per-keystroke timing is never computed or stored, only aggregate counts. | `PRIVACY.md:9` | Correct the wording. |

---

## Fix priority — highest trust-per-effort

Five changes close every High and most of the Mediums — and they are the changes
that directly answer "is this thing spying on me?"

- [ ] **1. Redact calendar titles &amp; bundle IDs from logs; flip `BlinkLogger` to `privacy: .private`.** Closes H1, M1, M2, L5.
- [ ] **2. Rewrite `PRIVACY.md` and the "no storage" rationale line to match actual behavior.** Closes H2, I8, part of M1.
- [ ] **3. Wire up `pruneOldRecords()` at launch (and add a Gabor retention cap).** Closes M4, L4.
- [ ] **4. Harden `install.sh` with a codesign + Team-ID + spctl check before launch.** Closes M3.
- [ ] **5. Persist only `eventKey` in `PauseMode`; clamp `UserDefaults` knobs on read.** Closes L3, L12.

### Remaining backlog (schedule after the above)

- [ ] L1 / L2 — update rollback protection + feed-URL hygiene
- [ ] L6 — evaluate dropping the app-level `network.client` entitlement
- [ ] L7 — auto-pause only for accepted/organized calendar events
- [ ] L8 — meeting-link host/scheme allowlist (latent hardening)
- [ ] L10 / L11 / M5 — CI/release supply-chain pinning
- [ ] L13 — fix or remove the dead "Base interval" setting
- [ ] I1–I7 — hygiene sweep (file modes, prune timer, dead code, dev server bind)

---

## Methodology &amp; scope

- **Dimensions audited (8):** input-capture privacy · persistence-at-rest ·
  logging &amp; export · auto-update (Sparkle) &amp; network trust · entitlements /
  sandbox / TCC · calendar &amp; meeting-link handling · IPC / XPC / process /
  injection surface · supply-chain / build-release / repo hygiene.
- **Verification:** every finding was independently re-checked against source by a
  refute-lens verifier (default to "not real" unless the code supports it) and an
  impact-lens verifier (calibrate severity honestly). A completeness critic then
  hunted for missed surfaces (overlay/global key monitor, notifications, web
  views, onboarding TOCTOU, event-tap thread safety, `BlinkCore` internals,
  on-disk state tampering, export-compliance, website copy) — all clean or
  low/info.
- **Refuted / dropped during verification:** a suspected clipboard auto-copy of
  logs (`LogExporter.exportToClipboard` is unreachable dead code; the real
  sharing path is Finder reveal of raw files) and an over-broad "no `Process()`
  anywhere" claim (one benign debug self-relaunch exists, see I4).
- **"Local only"** marks issues where the data never leaves the Mac — a
  privacy/honesty gap, not exfiltration.
