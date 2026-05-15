# How Flow Detection Works

Blink learns your work rhythm over 20 minutes. When the timer fires, it looks at how you've been working and makes one decision: extend your session, remind you to take a break, or stay quiet.

## What Blink Decides

| Your activity | What happens |
|--------------|-------------|
| Deep work (intense typing, low app switching) | Timer extended 10 min + gentle nudge |
| Active but casual (browsing, email) | Break overlay (20 seconds) |
| Light screen time (reading, occasional scrolling) | Gentle nudge toast |
| Barely at screen (mostly away) | Silent reset — no interruption |

## What Blink Looks At

- **Typing intensity** — strongest signal of focused work
- **Click frequency** — designers click a lot, that counts
- **App switching** — fewer switches = more focused
- **Which app you're in** — editors and design tools get a bonus
- **Scrolling without typing** — consumption, not creation

Mouse movement is ignored — everyone moves their mouse constantly, even while casually browsing.

## Sensitivity

The sensitivity slider controls how easily Blink recognizes deep work:

- **Low (40%)** — strict, prioritizes eye health. Only very intense work extends the timer.
- **Default (70%)** — balanced. Most focused work extends, casual use gets breaks.
- **High (90%)** — relaxed. Almost any sustained activity extends the timer.

## Break Intervals

| | Duration | When |
|---|----------|------|
| Normal | 20 min | Default timer |
| Extended | 30 min | 1st extension (deep work detected) |
| Max | 40 min | 2nd extension (still deep work) |

After 40 minutes, Blink always reminds you — max 2 extensions per session.

## Scenarios

### Coding for 20 minutes
Steady typing at 60+ keys/min. Low app switching. In VS Code.
→ **Deep work detected. Timer extended to 30 min, gentle nudge.**

### Designing in Figma
Lots of clicking and dragging. Some keyboard shortcuts. Low app switching.
→ **Deep work detected. Timer extended to 30 min.**

### Browsing Reddit for 20 minutes
Lots of scrolling, some clicks, barely any typing. Frequent tab switching.
→ **Casual use. Break overlay at 20 min.**

### Chatting occasionally while away from desk
A few messages typed, some scrolling. Mostly away from screen.
→ **Too little activity. Silent reset — no interruption.**

### Reading a long document
Occasional scrolling, no typing. Still staring at screen.
→ **Light activity. Gentle nudge to rest your eyes.**

### Getting coffee (away 3+ minutes)
No input at all for 3 minutes.
→ **Idle detected. Timer resets silently. Fresh start when you return.**

### On a Zoom call
Mic active — detected immediately.
→ **Timer pauses completely. Resumes when call ends.**

### Watching a YouTube video
Video playing in the browser.
→ **Timer pauses — you're already resting your focus.**

## Why Breaks Matter During Focus

Research shows your eyes strain **most** during exactly the kind of focused work that extends the timer:

- **Blink rate drops 69%** during active typing (5/min vs 15/min normal)
- **92% of blinks become incomplete** during focused screen work
- **4+ hours** of screen time nearly doubles dry eye risk

This is why Blink's default setting still delivers reminders during deep work — just gently, at natural moments.

## Privacy

Blink learns your work rhythm — never your content:
- When keys are pressed (never which keys)
- When clicks and scrolls happen (never where)
- Which type of app is active (creative vs consumption)

All data stays local. No analytics, no telemetry.
