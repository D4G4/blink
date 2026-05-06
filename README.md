# Blink

**Smart 20-20-20 eye break reminder for macOS and Windows.**

Every 20 minutes of screen time, look at something 20 feet away for 20 seconds. Blink makes this effortless by detecting your work patterns and prompting at the right moment — never mid-thought.

## Download

### macOS

1. Download the latest `.dmg` from [Releases](../../releases)
2. Open the DMG and drag **Blink** to Applications
3. Launch Blink — it appears as an icon in your menu bar
4. Grant **Accessibility** permission when prompted (required for smart break detection)
5. First-timers: right-click the app and select **Open** if you see a Gatekeeper warning

> **Requires macOS 14 (Sonoma) or later.**

### Windows

Coming soon. The core logic is complete — see `blink-windows/`.

## What makes it smart

Most break reminder apps are dumb timers that interrupt you at the worst possible moment. Blink watches *how* you work (never *what*) and adapts:

| Feature | What it does |
|---|---|
| **Flow detection** | Monitors typing rhythm and app switching to detect deep focus. Extends the timer so you're not interrupted mid-thought. |
| **Natural pause waiting** | When you're focused, waits for a 6-second gap in your input before showing the break — not a jarring mid-keystroke popup. |
| **Walk-away detection** | If you leave your desk for 90+ seconds, Blink counts that as a break and silently resets. |
| **Video awareness** | Detects when you're watching video (YouTube, Netflix, etc.) and pauses the timer. |
| **Meeting detection** | Pauses automatically during calls so you're never interrupted in a meeting. |
| **Agent workflow aware** | Knows the difference between "waiting for AI to respond" (still at screen) and "walked away" (actually resting). |

## How it works

1. A small icon sits in your menu bar — click it to see your timer and stats
2. When it's time for a break, a gentle toast appears in the corner (3-second heads-up)
3. Then a fullscreen overlay counts down 20 seconds — look at something far away
4. Press **Esc** to skip, **→** to extend by 20 seconds
5. Timer resets and the cycle continues

## Themes

Pick your vibe during onboarding or change anytime in Preferences:

**Peach** · **Sage** · **Sand** · **Midnight** · **Mono**

Each theme colors the menu bar popup, break overlay, and settings. Mono is dark-mode-aware — it inverts automatically.

## Privacy

Blink monitors your input patterns (keystroke timing, app switches, mouse behavior) to detect flow state. It **never** records what you type, which apps you use by name, or any content. All data stays on your machine in `~/Library/Application Support/Blink/`.

## Building from source

### macOS

```bash
cd blink-macos
brew install xcodegen  # if not installed
xcodegen generate
open Blink.xcodeproj
# Cmd+R to run
```

### Windows

```bash
cd blink-windows
# Open Blink.Windows.slnx in Visual Studio 2022
# or: dotnet build src/Blink.Core
# Tests: dotnet test
```

### Running tests

```bash
# macOS (Swift)
cd blink-macos/BlinkCore && swift test  # 85 tests

# Windows / cross-platform (C#)
cd blink-windows && dotnet test          # 74 tests
```

## Project structure

```
blink-macos/              # Swift / SwiftUI
├── Blink/                 # App target (menu bar, overlay, onboarding, themes)
├── BlinkCore/             # Pure logic package (flow detection, timer, compliance)
└── project.yml            # XcodeGen spec

blink-windows/             # C# / WinUI 3
└── src/
    ├── Blink.Core/        # Port of BlinkCore
    ├── Blink.Core.Tests/  # xUnit tests
    ├── Blink.Platform/    # Win32 adapters (P/Invoke)
    └── Blink.App/         # WinUI 3 app
```

## License

MIT
