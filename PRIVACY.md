# Privacy Policy

**Blink** is a desktop eye break reminder. Your privacy is simple: we don't collect anything.

## What Blink accesses

Blink uses macOS **Input Monitoring** permission to observe:

- **Keystroke timing** (how fast you type, pauses between keystrokes)
- **Mouse movement patterns** (speed, distance, scroll events)
- **App switches** (which app is frontmost — via public `NSWorkspace` notifications, no permission needed)

It also uses macOS **Microphone** permission to read one bit of state — whether any app is currently capturing audio — so the break timer can pause during calls. No audio is recorded or transmitted.

Optionally, if you enable meeting auto-pause, Blink uses macOS **Calendar** permission to read the times of your events so it can pause during meetings. Event details are read on your Mac and never stored or transmitted.

This data is used **only** to detect flow state and decide when to show a break reminder.

## What Blink does NOT access

- Keystrokes content (what you type)
- Window contents or titles
- URLs or browsing history
- Files or documents
- Contacts or email
- Location
- Any personal or identifiable information

## Data storage

All data is stored **locally on your device** in daily JSON files:

- **macOS:** `~/Library/Application Support/Blink/`
- **Windows:** `%LOCALAPPDATA%\Blink\`

Files older than 30 days are automatically deleted. No data is ever transmitted off your device.

## Network access

Blink makes **one kind of network call**: checking for updates. Once a day (and shortly after launch) the app fetches `https://blink20.net/appcast.xml` using the open-source [Sparkle](https://sparkle-project.org/) framework, and downloads new versions from GitHub Releases. That request carries only what any HTTPS request carries plus the standard Sparkle user agent (e.g. `Blink/5.2.3 Sparkle/2.9`). No user data is sent. Blink contains no analytics SDK, no telemetry, and no tracking, and nothing about your usage of the app ever leaves your Mac.

**What our update server counts.** blink20.net keeps a daily tally of how many update checks and website downloads it receives, broken down by app version and operating system — so we know roughly how many people use Blink and which versions are out there. It does not log IP addresses, does not set cookies, and does not store anything per request or per person; the only thing retained is a number per day per version. You can read the code that does this in [`worker/index.js`](https://github.com/D4G4/blink/blob/main/worker/index.js).

## Third-party services

Blink bundles one open-source framework, Sparkle, for updates. Updates are served from Cloudflare (blink20.net) and GitHub Releases. There are no analytics platforms, SDKs, or other third-party services.

## Open source

Blink is fully open source. You can verify every claim in this policy by reading the code at [github.com/D4G4/blink](https://github.com/D4G4/blink).

## Contact

Questions about privacy? Open an issue on GitHub or email dakshg18@gmail.com.

*Last updated: August 24, 2026*
