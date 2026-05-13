# Privacy Policy

**Blink** is a desktop eye break reminder. Your privacy is simple: we don't collect anything.

## What Blink accesses

Blink uses macOS Accessibility permission to monitor:

- **Keystroke timing** (how fast you type, pauses between keystrokes)
- **Mouse movement patterns** (speed, distance, scroll events)
- **App switches** (how often you switch between apps)
- **Microphone/camera status** (on or off, for meeting detection)

This data is used **only** to detect flow state and decide when to show a break reminder.

## What Blink does NOT access

- Keystrokes content (what you type)
- Window contents or titles
- URLs or browsing history
- Files or documents
- Contacts, calendar, or email
- Location
- Any personal or identifiable information

## Data storage

All data is stored **locally on your device** in daily JSON files:

- **macOS:** `~/Library/Application Support/Blink/`
- **Windows:** `%LOCALAPPDATA%\Blink\`

Files older than 30 days are automatically deleted. No data is ever transmitted off your device.

## Network access

Blink makes **one optional network call**: checking GitHub Releases for updates. This is a simple HTTPS GET request to `api.github.com`. No user data is sent. No analytics. No telemetry. No tracking.

## Third-party services

None. Blink has zero dependencies on third-party services, SDKs, or analytics platforms.

## Open source

Blink is fully open source. You can verify every claim in this policy by reading the code at [github.com/D4G4/blink](https://github.com/D4G4/blink).

## Contact

Questions about privacy? Open an issue on GitHub or email dakshg18@gmail.com.

*Last updated: May 13, 2026*
