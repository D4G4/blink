# How Flow Detection Works

Blink uses a simple, predictable model to detect when you're focused: **activity gaps**.

If you've been continuously active — any keyboard or mouse input — with no long pauses, Blink considers you in flow and extends your break interval.

## The Rule

| State | Condition | Break interval |
|-------|-----------|---------------|
| Normal | Default | 20 min |
| Flow | Active for 3+ min (no gap > tolerance) | 30 min |
| Deep Flow | In flow for 15+ min | 40 min |
| Idle | No input for 3 min | Timer resets silently |
| Meeting | Mic or camera active | Timer pauses |

## What "Active" Means

Blink checks every 30 seconds: how long since the last keyboard or mouse input?

- If the gap is **within your tolerance** → you're active
- If the gap **exceeds your tolerance** → activity streak breaks

That's it. No weighted scores, no app categorization, no complicated heuristics.

## Sensitivity = Gap Tolerance

The sensitivity slider controls how long you can pause between actions and stay in flow:

| Sensitivity | Gap Tolerance | Description |
|-------------|--------------|-------------|
| 40% | 15s | Strict — only continuous typing counts |
| 50% | 25s | Short thinking pauses OK |
| 60% | 35s | Brief reading won't break flow |
| **70% (default)** | **60s** | **Natural thinking and reading stay in flow** |
| 80% | 60s | Can read for 1 minute |
| 90% | 90s | Very forgiving — 90s pauses OK |

## Scenarios

### Coding for 10 minutes
You're typing steadily with short pauses to think (< 60s each). Blink detects flow after 3 minutes. Timer extends to 30 min. After 15 min of sustained activity, deep flow — 40 min.

**Result:** Gentle toast nudge at 30–40 min ("You've been focused for 40 min — time for a break?"). Auto-dismisses in 7 seconds. Never forces a fullscreen overlay during flow.

### Reading docs for 2 minutes, then coding
You read without touching the keyboard for 90 seconds, then start typing. At default sensitivity (60s tolerance), the 90s pause breaks flow.

**Result:** Flow resets. Timer stays at 20 min until you're active for 3 min again.

### Switching between editor and browser
You switch apps frequently but keep typing and clicking. Every gap between inputs is under 60 seconds.

**Result:** Flow stays active — it's based on input gaps, not which app you're in.

### Getting coffee (away 5 minutes)
No keyboard or mouse input for 5 minutes. Blink detects you're away after 3 minutes.

**Result:** Timer resets silently. No break shown — your eyes already rested.

### On a Zoom/Teams call
Microphone is active. Blink detects this immediately.

**Result:** Timer pauses completely. Resumes when the call ends. Any mic usage triggers this — calls, dictation, voice recording.

### Watching a YouTube video
Video is playing in the browser. No keyboard/mouse input.

**Result:** Timer pauses — you're already resting your focus on fixed content.

### Deep in flow, timer fires
You've been coding for 40 minutes straight. Timer reaches zero.

**Result:** Gentle toast in bottom-right corner: "You've been focused for 40 min — time for a break?" with a "Break" button. Auto-dismisses after 7 seconds. Timer resets for another 20 min. **Never forces the fullscreen overlay during flow.**

### Not in flow, timer fires
You've been browsing casually for 20 minutes. Timer reaches zero. No recent sustained activity.

**Result:** 3-second countdown toast → fullscreen break overlay (20 seconds). Press Esc to skip, → to extend 20s.

### 4+ consecutive breaks without walking
You've taken 4 breaks in a row without leaving your desk (no idle period > 3 min between them).

**Result:** The break overlay adds a suggestion: "You've taken 4+ breaks — consider a quick walk!" Resets when you step away for 3+ minutes.

## What Blink Monitors

- **Keyboard timing** — when keys are pressed (never which keys)
- **Mouse movement** — movement patterns, clicks, scrolls (never position or content)
- **Microphone status** — on/off (never audio content)
- **Video playback** — playing/paused (never what's playing)
- **Idle time** — seconds since last input

## What Blink Does NOT Monitor

- What you type (keystrokes, passwords, messages)
- What's on screen (window contents, URLs, documents)
- Which apps you use (app identity is not used for flow detection)
- Your location, contacts, calendar, or any personal data

All data stays local. No analytics, no telemetry. The only network call is an optional update check against GitHub Releases.
