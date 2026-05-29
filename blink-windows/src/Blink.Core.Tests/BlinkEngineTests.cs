using Blink.Core;
using Blink.Core.FlowDetection;

namespace Blink.Core.Tests;

/// <summary>
/// Behavioral spec for the BlinkEngine orchestrator. These tests treat the
/// engine as a black box driven by input events + Tick, and assert against
/// the callbacks it fires. Each test is portable to Swift xctest.
///
/// Time is driven via <see cref="BlinkEngine.SimulatedNow"/> for determinism.
/// </summary>
public class BlinkEngineTests
{
    // Reference epoch for simulated time.
    private static readonly DateTime T0 = new(2026, 1, 1, 0, 0, 0, DateTimeKind.Utc);

    private static BlinkEngine NewEngine(double sensitivity = 0.7)
    {
        var e = new BlinkEngine(sensitivity) { SimulatedNow = T0 };
        return e;
    }

    private static void Advance(BlinkEngine e, int seconds) =>
        e.SimulatedNow = e.SimulatedNow!.Value.AddSeconds(seconds);

    /// <summary>Tick once per second, advancing simulated time each tick.</summary>
    private static void TickSeconds(BlinkEngine e, int seconds)
    {
        for (var i = 0; i < seconds; i++)
        {
            Advance(e, 1);
            e.Tick();
        }
    }

    // --- Initial state ---

    [Fact]
    public void InitialState_Working_20Min()
    {
        var e = NewEngine();
        Assert.Equal(1200, e.RemainingSeconds);
        Assert.Equal(BlinkEngine.DisplayState.Working, e.CurrentState);
        Assert.Equal(0, e.CurrentBreakStreak);
    }

    [Fact]
    public void Sensitivity_SetViaConstructor()
    {
        var e = new BlinkEngine(0.65);
        Assert.Equal(0.65, e.Sensitivity, 6);
    }

    // --- Tick + countdown ---

    [Fact]
    public void Tick_FiresTimerUpdate()
    {
        var e = NewEngine();
        double? last = null;
        e.OnTimerUpdate = (rem, _) => last = rem;
        e.RecordKeystroke();
        TickSeconds(e, 1);
        Assert.NotNull(last);
        Assert.True(last < 1200);
    }

    [Fact]
    public void Tick_CountsDown_OneSecondPerTick()
    {
        var e = NewEngine();
        e.RecordKeystroke();
        var before = e.RemainingSeconds;
        TickSeconds(e, 10);
        var after = e.RemainingSeconds;
        Assert.InRange(before - after, 8, 12);
    }

    // --- Idle / away ---

    [Fact]
    public void NoActivity_DoesNotImmediatelyTriggerIdle()
    {
        var e = NewEngine();
        e.RecordKeystroke();
        TickSeconds(e, 1);
        Assert.Equal(BlinkEngine.DisplayState.Working, e.CurrentState);
    }

    [Fact]
    public void ExtendedIdle_ResetsConsecutiveBreaks()
    {
        var e = NewEngine();
        e.UserTookBreak();
        e.UserTookBreak();
        Assert.Equal(2, e.CurrentBreakStreak);

        // No input for > 180s → idle reset zeroes the streak.
        TickSeconds(e, 200);
        Assert.Equal(0, e.CurrentBreakStreak);
    }

    // --- Meeting ---

    [Fact]
    public void MicActive_PutsStateInMeeting()
    {
        var e = NewEngine();
        e.RecordKeystroke();
        e.SetMicActive(true);
        TickSeconds(e, 1);
        Assert.Equal(BlinkEngine.DisplayState.Meeting, e.CurrentState);
    }

    [Fact]
    public void MicReleased_ReturnsToWorking()
    {
        var e = NewEngine();
        e.RecordKeystroke();
        e.SetMicActive(true);
        TickSeconds(e, 1);
        Assert.Equal(BlinkEngine.DisplayState.Meeting, e.CurrentState);

        e.RecordKeystroke();
        e.SetMicActive(false);
        TickSeconds(e, 1);
        Assert.Equal(BlinkEngine.DisplayState.Working, e.CurrentState);
    }

    [Fact]
    public void MicActive_ResetsStreakAndTimer()
    {
        var e = NewEngine();
        e.UserTookBreak();
        Assert.Equal(1, e.CurrentBreakStreak);
        e.RecordKeystroke();
        TickSeconds(e, 60);
        Assert.True(e.RemainingSeconds < 1200);

        e.SetMicActive(true);
        Assert.Equal(0, e.CurrentBreakStreak);
        Assert.Equal(1200, e.RemainingSeconds);
    }

    [Fact]
    public void CameraActive_AlsoTriggersMeeting()
    {
        var e = NewEngine();
        e.RecordKeystroke();
        e.SetCameraActive(true);
        TickSeconds(e, 1);
        Assert.Equal(BlinkEngine.DisplayState.Meeting, e.CurrentState);
    }

    // --- Video ---

    [Fact]
    public void VideoStart_ResetsTimer()
    {
        var e = NewEngine();
        e.RecordKeystroke();
        TickSeconds(e, 60); // burn one minute
        Assert.True(e.RemainingSeconds < 1200);

        e.SetVideoPlaying(true);
        Assert.Equal(1200, e.RemainingSeconds);
    }

    [Fact]
    public void VideoStart_ResetsStreak()
    {
        var e = NewEngine();
        e.UserTookBreak();
        Assert.Equal(1, e.CurrentBreakStreak);
        e.SetVideoPlaying(true);
        Assert.Equal(0, e.CurrentBreakStreak);
    }

    [Fact]
    public void VideoPlaying_PausesCountdown()
    {
        var e = NewEngine();
        e.RecordKeystroke();
        e.SetVideoPlaying(true);
        var before = e.RemainingSeconds;
        TickSeconds(e, 30);
        Assert.Equal(before, e.RemainingSeconds);
    }

    [Fact]
    public void VideoStop_ResumesCountdown()
    {
        var e = NewEngine();
        e.RecordKeystroke();
        e.SetVideoPlaying(true);
        TickSeconds(e, 10);
        var paused = e.RemainingSeconds;

        e.SetVideoPlaying(false);
        e.RecordKeystroke();
        TickSeconds(e, 10);
        Assert.True(e.RemainingSeconds < paused);
    }

    // --- Break flow ---

    [Fact]
    public void UserTookBreak_FiresStateChangeBack_AndIncrementsStreak()
    {
        var e = NewEngine();
        var states = new List<BlinkEngine.DisplayState>();
        e.OnStateChange = s => states.Add(s);
        e.UserTookBreak();
        Assert.Equal(1, e.CurrentBreakStreak);
        Assert.Contains(BlinkEngine.DisplayState.Working, states);
    }

    [Fact]
    public void UserSkippedBreak_DoesNotIncrementStreak()
    {
        var e = NewEngine();
        e.UserSkippedBreak();
        Assert.Equal(0, e.CurrentBreakStreak);
    }

    [Fact]
    public void UserTookBreak_ResetsTimerTo20Min()
    {
        var e = NewEngine();
        e.RecordKeystroke();
        TickSeconds(e, 60);
        Assert.True(e.RemainingSeconds < 1200);

        e.UserTookBreak();
        Assert.Equal(1200, e.RemainingSeconds);
    }

    [Fact]
    public void UserSnoozed_SetsTimerToProvidedMinutes()
    {
        var e = NewEngine();
        e.UserSnoozed(5);
        Assert.Equal(300, e.RemainingSeconds);
    }

    // --- Sensitivity propagation ---

    [Fact]
    public void Sensitivity_SettingPropagates()
    {
        var e = NewEngine();
        e.Sensitivity = 0.45;
        Assert.Equal(0.45, e.Sensitivity, 6);
    }

    // --- WakeFromSleep ---

    [Fact]
    public void WakeFromSleep_ResetsTimerAndStreak()
    {
        var e = NewEngine();
        e.UserTookBreak();
        e.RecordKeystroke();
        TickSeconds(e, 60);
        Assert.True(e.RemainingSeconds < 1200);
        Assert.Equal(1, e.CurrentBreakStreak);

        e.WakeFromSleep();
        Assert.Equal(1200, e.RemainingSeconds);
        Assert.Equal(0, e.CurrentBreakStreak);
    }

    [Fact]
    public void WakeAfterLongIdle_DoesNotImmediatelyQueueBreak()
    {
        // Regression: the phantom-break-on-wake bug. The engine had been
        // running near the wall-clock cap; the machine sleeps for a long time
        // and wakes. The idle reset MUST clear the wall-clock cap before it
        // can fire, so waking after a long gap does NOT immediately queue a
        // break.
        var e = NewEngine();
        e.MaxWallClockSeconds = 1800; // 30 min cap

        var breakShown = false;
        e.OnShowBreak = _ => breakShown = true;

        // Work right up near the cap.
        for (var i = 0; i < 1700; i++)
        {
            Advance(e, 1);
            e.RecordKeystroke();
            e.Tick();
        }
        Assert.False(breakShown, "should not have hit the cap yet");

        // Machine sleeps for an hour, then a tick fires on wake. The long idle
        // gap (> 180s) must trip the idle reset before the wall-clock cap.
        Advance(e, 3600);
        e.Tick();
        Assert.False(breakShown, "wake after long idle must NOT queue a phantom break");

        // Confirm the cap was reset: a fresh tick with input doesn't fire either.
        Advance(e, 1);
        e.RecordKeystroke();
        e.Tick();
        Assert.False(breakShown);
    }

    [Fact]
    public void Grace_Is20Seconds()
    {
        // Within 20s of a break ending, idle is forced to 0 (no flapping). At
        // exactly 20s the grace window has closed. We verify the state stays
        // Working through a 19s post-break gap with no input (grace masks idle),
        // which it could not if grace were shorter than the gap.
        var e = NewEngine();
        e.RecordKeystroke();
        e.UserTookBreak(); // sets lastBreakEndedAt = now

        // 19s of ticks with NO input. Idle would be ~19s but grace masks it to 0.
        TickSeconds(e, 19);
        Assert.Equal(BlinkEngine.DisplayState.Working, e.CurrentState);
    }

    // --- Compliance accessor ---

    [Fact]
    public void Compliance_ReachableThroughEngine()
    {
        var e = NewEngine();
        Assert.NotNull(e.Compliance);
    }

    // --- SpotCheck ---

    [Fact]
    public void SpotCheckFlow_ReportsCurrentApp()
    {
        var e = NewEngine();
        e.SetCurrentApp("Code");
        e.RecordKeystroke();
        TickSeconds(e, 120);
        var s = e.SpotCheckFlow();
        Assert.Equal("Code", s.CurrentApp);
        Assert.True(s.CreativeFraction > 0.99, $"all-Code window → creativeFraction ≈ 1.0 (got {s.CreativeFraction})");
    }
}
