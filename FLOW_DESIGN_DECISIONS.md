# Flow Detection Design Decisions

A record of the key design conversations and decisions that shaped Blink's flow detection system.

## 1. The Original Problem

Users found the 5-scorer weighted system (V1) unpredictable. They couldn't understand why flow dropped. App switches for reference material killed the score. The system oscillated around thresholds during normal work patterns.

## 2. What Signals Do We Have?

We went back to basics and listed every raw signal:

**Keyboard:** key press timestamp (not which key), time since last key press
**Mouse:** mouse move (ambient), left click, right click, scroll
**App context:** app switch (timestamp + bundle ID), window title change, frontmost app
**System:** mic active, camera active, video playing, combined idle time
**Derived (V1 scorers):** keystroke rhythm, app switch frequency, mouse patterns, window stability, app category

## 3. Why Mouse Moves Are Noise

Everyone with a hand on their mouse/trackpad has mouse events constantly — even while casually browsing. Including mouse moves in flow detection meant EVERYONE entered flow after 3 minutes. This was the core V2 bug: "users report it never interrupts them."

**Decision:** Mouse moves count for idle detection (are you at your desk?) but NOT for flow detection.

## 4. Intentional vs Ambient Input

We split inputs into two categories:

| Input | Type | Why |
|-------|------|-----|
| Keyboard | Intentional | Requires conscious action |
| Clicks | Intentional | Deliberate interaction |
| Scrolling | Intentional | Active engagement |
| Mouse moves | Ambient | Constant, unconscious |

## 5. The Breakthrough: Evaluate at Break Time, Not Continuously

**The old approach (V1, V2, V3):** Detect flow early (3 min) → extend timer immediately → decide break delivery later.

**The problem:** Making a big decision (extend timer by 10+ min) based on only 3 minutes of data. By minute 3, we barely know anything.

**The new approach:** Timer always runs to 20 min. Collect signals the entire time. At 20 min, evaluate the FULL window of data and make ONE decision: extend, show break, or skip.

This is fundamentally better because:
- 20 minutes of data vs 3 minutes
- No premature extension
- The decision is "should I interrupt NOW?" not "should I extend?"
- All signals are available (keystroke density, app switches, scroll patterns, app context)

## 6. Three Decisions, Not Two

| Activity | Inputs/min | Decision |
|----------|-----------|----------|
| < 5/min | Sporadic (workout + occasional chat) | **Skip** — silently reset |
| 5+/min, low score | Moderate browsing, email | **Show break** — overlay |
| 5+/min, high score | Coding, designing, writing | **Extend** — nudge + 10 more min |

**The skip case:** If someone was barely using their computer (working out, chatting occasionally), showing a break overlay is dumb — they weren't staring at the screen. Silently reset.

## 7. Scoring at Break Time

When the 20-min timer fires, compute a work intensity score (0.0–1.0):

- **Keyboard density (40%):** 0 kpm = 0, 30+ kpm = 0.8, 80+ kpm = 1.0
- **Click density (20%):** Designers click 30+ cpm. Casual users 2-5 cpm.
- **App switch rate (20%):** Fewer switches = more focused
- **Creative app bonus (10%):** IDE, Figma, design tools
- **Scroll-only penalty (10%):** High scroll + no keyboard = consumption

Score vs threshold (adjusted by sensitivity) determines the decision.

## 8. Sensitivity Controls Threshold

- High sensitivity (0.9) → lower threshold (0.2) → easier to extend
- Default (0.7) → threshold (0.4)
- Low sensitivity (0.4) → higher threshold (0.7) → harder to extend

## 9. Max 2 Extensions

20 min → 30 min → 40 min max. After 40 min, always show break regardless of score.

## 10. Research Backing

### Eye strain is WORST during flow
- Blink rate drops 69% during active typing (5/min vs 15/min normal) — PMC 2021
- 92% of blinks become incomplete during focused screen work — ScienceDirect 2023
- 4+ hours screen time nearly doubles dry eye risk — PMC 2021

### Interruption timing matters
- Interruptions at task boundaries cost 32% less cognitive recovery — Frontiers 2024
- 2-15 second pauses during programming = working memory (thinking) — IEEE 2022
- The worst time to interrupt is mid-thought. The best time is between tasks.

### Breakpoint detection
Instead of interrupting after a fixed idle time (6s), we detect compound signals:
- Keyboard → mouse transition (finished typing, navigating)
- Typing burst → 30s+ silence (completed a unit of work)
- App switch after typing (context change)

## 11. The Casual Chat Bug

**Scenario:** User chatting with AI, typing a message every few minutes, scrolling through responses in between. Working out on the side.

**V2 bug:** Mouse moves kept everyone "active" → flow after 3 min → never interrupted
**V3 bug:** Scrolling through responses counted as intentional input → flow maintained during workout gaps

**Fix:** The BreakDecisionEngine evaluates DENSITY of input over 20 minutes. 50 keystrokes + 30 scrolls in 20 min = 4 inputs/min → below threshold → skip (silently reset). No dumb overlay for someone who was barely at their computer.

## 12. Strategy Versioning

All strategies are documented in `FlowDetectionStrategy.swift`. Switching is one line:

```swift
public static let current: FlowDetectionStrategy = .intentionalWithEscalation
```

| Version | Approach | Status |
|---------|----------|--------|
| V1 | 5-scorer weighted + hysteresis | Original, unpredictable |
| V2 | Activity gap, any input | Too permissive (mouse moves) |
| V3 | Intentional input + two-tier + escalation | Better, still has issues |
| Current | BreakDecisionEngine (20-min evaluation) | In testing |

## 13. Permission Flow (Sandbox)

- `AXIsProcessTrusted()` doesn't work in sandbox
- CGEventTap probe triggers unwanted Input Monitoring prompt
- Solution: manual confirm — user clicks "I've granted access", app probes THEN
- No polling, no automatic probing, no surprise prompts
