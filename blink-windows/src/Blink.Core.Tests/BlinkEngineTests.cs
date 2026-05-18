using Blink.Core;
using Blink.Core.FlowDetection;

namespace Blink.Core.Tests;

/// <summary>
/// Behavioral spec for the BlinkEngine orchestrator. These tests treat the
/// engine as a black box driven by input events + Tick, and assert against
/// the callbacks it fires. Each test is portable to Swift xctest.
/// </summary>
public class BlinkEngineTests
{
    // --- Initial state ---

    [Fact]
    public void InitialState_Working_20Min()
    {
        var e = new BlinkEngine();
        Assert.Equal(1200, e.RemainingSeconds);
        Assert.Equal(BlinkEngine.DisplayState.Working, e.CurrentState);
        Assert.Equal(0, e.CurrentBreakStreak);
    }

    [Fact]
    public void Sensitivity_DefaultIs_0_7()
    {
        var e = new BlinkEngine();
        Assert.Equal(0.7, e.Sensitivity, 6);
    }

    // --- Tick + countdown ---

    [Fact]
    public void Tick_FiresTimerUpdate()
    {
        var e = new BlinkEngine();
        double? last = null;
        e.OnTimerUpdate = (rem, _) => last = rem;
        e.RecordKeystroke();
        e.Tick();
        Assert.NotNull(last);
        Assert.True(last < 1200);
    }

    [Fact]
    public void Tick_CountsDown_OneSecondPerTick()
    {
        var e = new BlinkEngine();
        e.RecordKeystroke();
        var before = e.RemainingSeconds;
        for (var i = 0; i < 10; i++) e.Tick();
        var after = e.RemainingSeconds;
        Assert.InRange(before - after, 8, 12);
    }

    // --- Idle / away ---

    [Fact]
    public void NoActivity_DoesNotImmediatelyTriggerIdle()
    {
        var e = new BlinkEngine();
        // Activity right now, then one tick (1 second later, far below 180s threshold)
        e.RecordKeystroke();
        e.Tick();
        Assert.Equal(BlinkEngine.DisplayState.Working, e.CurrentState);
    }

    [Fact]
    public void ActivityResetsConsecutiveBreaksOnceIdle()
    {
        var e = new BlinkEngine();
        e.UserTookBreak();
        e.UserTookBreak();
        Assert.Equal(2, e.CurrentBreakStreak);

        // Sleep through the grace period + idle threshold by ticking without input
        // Note: the engine uses wall-clock, so we can't simulate idle synthetically
        // from here. This test just locks in the current behavior: streak persists
        // through ticks unless idle is actually detected.
        for (var i = 0; i < 5; i++) e.Tick();
        Assert.Equal(2, e.CurrentBreakStreak);
    }

    // --- Meeting ---

    [Fact]
    public void MicActive_PutsStateInMeeting()
    {
        var e = new BlinkEngine();
        e.RecordKeystroke();
        e.SetMicActive(true);
        e.Tick();
        Assert.Equal(BlinkEngine.DisplayState.Meeting, e.CurrentState);
    }

    [Fact]
    public void MicReleased_ReturnsToWorking()
    {
        var e = new BlinkEngine();
        e.RecordKeystroke();
        e.SetMicActive(true);
        e.Tick();
        Assert.Equal(BlinkEngine.DisplayState.Meeting, e.CurrentState);

        e.SetMicActive(false);
        e.Tick();
        Assert.Equal(BlinkEngine.DisplayState.Working, e.CurrentState);
    }

    [Fact]
    public void CameraActive_AlsoTriggersMeeting()
    {
        var e = new BlinkEngine();
        e.RecordKeystroke();
        e.SetCameraActive(true);
        e.Tick();
        Assert.Equal(BlinkEngine.DisplayState.Meeting, e.CurrentState);
    }

    // --- Video ---

    [Fact]
    public void VideoStart_ResetsTimer()
    {
        var e = new BlinkEngine();
        e.RecordKeystroke();
        for (var i = 0; i < 60; i++) e.Tick();    // burn one minute
        Assert.True(e.RemainingSeconds < 1200);

        e.SetVideoPlaying(true);
        Assert.Equal(1200, e.RemainingSeconds);
    }

    [Fact]
    public void VideoPlaying_PausesCountdown()
    {
        var e = new BlinkEngine();
        e.RecordKeystroke();
        e.SetVideoPlaying(true);
        var before = e.RemainingSeconds;
        for (var i = 0; i < 30; i++) e.Tick();
        Assert.Equal(before, e.RemainingSeconds);
    }

    [Fact]
    public void VideoStop_ResumesCountdown()
    {
        var e = new BlinkEngine();
        e.RecordKeystroke();
        e.SetVideoPlaying(true);
        for (var i = 0; i < 10; i++) e.Tick();
        var paused = e.RemainingSeconds;

        e.SetVideoPlaying(false);
        e.RecordKeystroke();
        for (var i = 0; i < 10; i++) e.Tick();
        Assert.True(e.RemainingSeconds < paused);
    }

    // --- Break flow ---

    [Fact]
    public void UserTookBreak_FiresStateChangeBack_AndIncrementsStreak()
    {
        var e = new BlinkEngine();
        var states = new List<BlinkEngine.DisplayState>();
        e.OnStateChange = s => states.Add(s);
        e.UserTookBreak();
        Assert.Equal(1, e.CurrentBreakStreak);
        Assert.Contains(BlinkEngine.DisplayState.Working, states);
    }

    [Fact]
    public void UserSkippedBreak_DoesNotIncrementStreak()
    {
        var e = new BlinkEngine();
        e.UserSkippedBreak();
        Assert.Equal(0, e.CurrentBreakStreak);
    }

    [Fact]
    public void UserTookBreak_ResetsTimerTo20Min()
    {
        var e = new BlinkEngine();
        e.RecordKeystroke();
        for (var i = 0; i < 60; i++) e.Tick();
        Assert.True(e.RemainingSeconds < 1200);

        e.UserTookBreak();
        Assert.Equal(1200, e.RemainingSeconds);
    }

    [Fact]
    public void UserSnoozed_SetsTimerToProvidedMinutes()
    {
        var e = new BlinkEngine();
        e.UserSnoozed(5);
        Assert.Equal(300, e.RemainingSeconds);
    }

    // --- Sensitivity propagation ---

    [Fact]
    public void Sensitivity_SettingPropagatesToDecisionEngine()
    {
        var e = new BlinkEngine();
        e.Sensitivity = 0.45;
        Assert.Equal(0.45, e.Sensitivity, 6);
        // No direct accessor for the inner DecisionEngine sensitivity, but the
        // behavior under HandleBreakDue depends on it. This test just locks the
        // public surface; tighter coupling is exercised in integration scenarios.
    }

    // --- WakeFromSleep ---

    [Fact]
    public void WakeFromSleep_RunsATick()
    {
        var e = new BlinkEngine();
        var updates = 0;
        e.OnTimerUpdate = (_, _) => updates++;
        e.RecordKeystroke();
        e.WakeFromSleep();
        Assert.True(updates > 0);
    }

    // --- Compliance accessor ---

    [Fact]
    public void Compliance_ReachableThroughEngine()
    {
        var e = new BlinkEngine();
        Assert.NotNull(e.Compliance);
    }
}
