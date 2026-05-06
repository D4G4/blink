<p align="center">
  <img src="blink-macos/Blink/Assets.xcassets/AppIcon-Peach.imageset/icon.png" width="128" height="128" alt="Blink icon">
</p>

<h1 align="center">Blink</h1>

<p align="center">
  <strong>Smart 20-20-20 eye break reminder</strong><br>
  <em>for macOS and Windows</em>
</p>

<p align="center">
  <a href="../../releases/latest"><img src="https://img.shields.io/badge/download-macOS-blue?style=flat-square&logo=apple" alt="Download macOS"></a>
  <img src="https://img.shields.io/badge/platform-macOS%2014%2B-lightgrey?style=flat-square" alt="macOS 14+">
  <img src="https://img.shields.io/badge/license-MIT-green?style=flat-square" alt="MIT License">
</p>

---

Every 20 minutes of screen time, look at something 20 feet away for 20 seconds. Optometrists have recommended this since the 90s. The problem isn't the rule — it's the apps.

They interrupt you mid-thought. They fire a popup while you're in a meeting. They nag you when you already walked away 2 minutes ago. They don't care that you're deep in a coding session and interrupting now will cost you 23 minutes to get back into flow.

**Blink is different.** It watches *how* you work (never *what*) and breaks come at the right moment.

## Install

### macOS

1. **[Download Blink.dmg](../../releases/latest)** from the latest release
2. Open the DMG, drag **Blink** to Applications
3. Launch Blink — it appears as an icon in your menu bar
4. Grant **Accessibility** when prompted (required for smart detection)

> First launch: if macOS says "unidentified developer", right-click the app and select **Open**.

### Windows

Coming soon. Core logic is complete — see [`blink-windows/`](blink-windows/).

## What makes it smart

| | Feature | How it works |
|---|---|---|
| **Brain icon** | **Flow detection** | Monitors typing rhythm and app switching. When you're in deep focus, the timer extends from 20 to 30-40 minutes. |
| **Hand icon** | **Natural pause waiting** | Doesn't interrupt mid-keystroke. Waits for a 6-second gap in your input — a natural thought boundary. |
| **Walk icon** | **Walk-away detection** | Left your desk for 90+ seconds? That counts as a break. Timer resets silently. |
| **Play icon** | **Video awareness** | Watching YouTube or Netflix? Timer pauses — you're already resting your focus. |
| **Video icon** | **Meeting detection** | Mic or camera active? Timer pauses. No interruptions during calls. |
| **AI icon** | **Agent workflow aware** | Waiting for an AI response while scrolling? Timer keeps running. Sitting perfectly still for 90s? That's a walk-away. |

## How it works

```
You work normally
        |
    20 minutes pass (or 30-40 in flow)
        |
    Toast appears in corner: "Break in 3s"
        |
    Fullscreen overlay: look away for 20 seconds
        |
    [esc] skip    [->] extend 20s
        |
    Timer resets. Cycle continues.
```

The app lives in your menu bar. Click to see your timer, flow state, and break stats.

## Themes

Choose during onboarding or change anytime in Preferences.

**Peach** · **Sage** · **Sand** · **Midnight** · **Mono**

Mono is dark-mode-aware — colors invert automatically.

## Privacy

Blink monitors input *timing* (keystroke cadence, app switch frequency, mouse patterns) to detect flow state. It **never** logs:
- What you type
- Which apps you use
- Window contents or titles
- Any personal data

All data stays local in `~/Library/Application Support/Blink/` as daily JSON files. No network calls. No analytics. No telemetry.

## The 20-20-20 rule

Coined by optometrist Dr. Jeffrey Anshel in 1991:

> Every **20** minutes, look at something **20** feet away, for **20** seconds.

Your blink rate drops from 15/min to 4/min during screen work. This causes dry eyes, headaches, and blurred vision. A 20-second break lets your eye muscles relax and reset.

## Building from source

### macOS

```bash
cd blink-macos
brew install xcodegen
xcodegen generate
open Blink.xcodeproj   # Cmd+R to run
```

### Windows

Open `blink-windows/Blink.Windows.slnx` in Visual Studio 2022.

### Tests

```bash
# macOS — 85 tests
cd blink-macos/BlinkCore && swift test

# Windows — 74 tests (runs on Mac too)
cd blink-windows && dotnet test
```

## Architecture

```
blink-macos/                    blink-windows/
├── BlinkCore/                  ├── Blink.Core/
│   ├── FlowDetection/         │   ├── FlowDetection/
│   │   ├── 5 signal scorers   │   │   ├── 5 signal scorers
│   │   ├── FlowScoreCalc      │   │   ├── FlowScoreCalc
│   │   └── FlowStateMachine   │   │   └── FlowStateMachine
│   ├── Timer/                  │   ├── Timer/
│   └── Compliance/             │   └── Compliance/
├── Blink/                      ├── Blink.Platform/
│   ├── Platform/ (CGEventTap)  │   ├── WinInputMonitor (hooks)
│   ├── MenuBar/                │   ├── WinAppMonitor
│   ├── Overlay/                │   └── WinIdleDetector
│   ├── Onboarding/             └── Blink.App/
│   ├── Settings/                   ├── TrayIcon/
│   └── Theme/                      ├── Overlay/
└── project.yml                     └── Theme/
```

The core logic (flow detection, timer, compliance) is platform-agnostic. Platform adapters implement 4 interfaces:
- `InputEventSource` — keyboard/mouse timing
- `AppActivitySource` — app switches, window changes
- `IdleStateSource` — time since last input
- `ContextSource` — meetings, video, fullscreen

## License

MIT
