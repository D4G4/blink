# How Flow Detection Works

Blink detects focused work by tracking **intentional input** — typing, clicking, and scrolling. Mouse movement alone doesn't count (it's ambient — everyone moves their mouse constantly, even while browsing casually).

## The Rule

| State | How it's detected | Break interval |
|-------|------------------|---------------|
| Normal | Default | 20 min |
| Flow | Sustained intentional input for 3+ min | 30 min |
| Deep Flow | In flow for 15+ min | 40 min |
| Idle | No input at all for 3 min | Timer resets silently |
| Meeting | Mic or camera active | Timer pauses |

## What Counts as "Intentional Input"

| Input | Counts for flow? | Counts for idle? |
|-------|-----------------|-----------------|
| Keyboard (typing) | **Yes** — strongest signal | Yes |
| Mouse clicks | **Yes** — intentional interaction | Yes |
| Scrolling | **Yes** — active engagement | Yes |
| Mouse movement | **No** — ambient, constant | Yes |

## Two-Tier Gap Tolerance

Flow uses two different thresholds:

- **Entry tolerance**: how long you can pause and still build toward flow (stricter)
- **Maintenance tolerance**: how long you can pause and stay in flow once entered (1.5x more forgiving)

This handles agent/AI workflows: you type a prompt, wait 60-90 seconds while scrolling through the AI's response, then type again. The maintenance tolerance keeps you in flow during the wait.

| Sensitivity | Entry tolerance | Maintenance tolerance |
|-------------|---------------|----------------------|
| 40% (strict) | 15s | 22s |
| 50% | 30s | 45s |
| 60% | 45s | 67s |
| **70% (default)** | **60s** | **90s** |
| 80% | 75s | 112s |
| 90% (relaxed) | 90s | 135s |

## Natural Breakpoint Detection

When a break is due during flow, Blink doesn't interrupt immediately. It waits for a **natural task boundary** — a moment between thoughts, not during one.

Research shows that 2-15 second pauses indicate active working memory processing (thinking about syntax, logic). Interrupting during these pauses costs 32% more cognitive recovery than interrupting at task boundaries.

Blink detects breakpoints using compound signals:

| Signal | What it means |
|--------|-------------|
| Keyboard → mouse transition | Stopped typing, started clicking = finished a thought |
| Typing burst → 30s+ silence | Completed a unit of work |
| App switch after typing | Moved to different context |

## Break Delivery

What happens when the timer fires depends on your state and sensitivity:

**Not in flow** → forced overlay (20s break). You're not deeply focused, so the interruption cost is low.

**In flow** → Blink waits for a natural breakpoint, then:
- At low sensitivity (40-50%): forced overlay after 1 ignored nudge
- At default (70%): gentle nudge, forced overlay after 3 ignored nudges
- At high sensitivity (90%): gentle nudge only, never forced

## Walk Suggestion

After 4+ consecutive breaks without leaving your desk (no 3-minute idle period), the break overlay adds: "Consider a quick walk!" Resets when you step away.

## Why Breaks Matter During Flow

Research shows your eyes strain **most** during exactly the kind of focused work that triggers flow:

- **Blink rate drops 69%** during active typing (5/min vs 15/min normal)
- **92% of blinks become incomplete** during focused screen work
- **4+ hours** of screen time nearly doubles dry eye risk

This is why Blink's default (70%) still delivers breaks during flow — just at natural moments. Higher sensitivity settings reduce break frequency, but your eyes pay the cost.

## Privacy

Blink monitors input **timing** only:
- When keys are pressed (never which keys)
- When clicks and scrolls happen (never where or what)
- When you switch apps (never which apps — app identity is not used for flow detection in V3)

All data stays local. No analytics, no telemetry.
