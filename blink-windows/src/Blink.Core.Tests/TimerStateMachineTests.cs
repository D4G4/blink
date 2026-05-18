using Blink.Core.FlowDetection;
using Blink.Core.Timer;

namespace Blink.Core.Tests;

public class TimerStateMachineTests
{
    [Fact] public void InitialState_20Min() =>
        Assert.Equal(1200, new TimerStateMachine().RemainingSeconds);

    [Fact]
    public void Countdown_DecreasesRemaining()
    {
        var timer = new TimerStateMachine();
        timer.Tick(FlowState.Normal, 60);
        Assert.Equal(1140, timer.RemainingSeconds);
    }

    [Fact]
    public void BreakDue_Fires()
    {
        var timer = new TimerStateMachine();
        var fired = false;
        timer.OnBreakDue += () => fired = true;
        timer.Tick(FlowState.Normal, 1200);
        Assert.True(fired);
        Assert.Equal(0, timer.RemainingSeconds);
    }

    [Fact]
    public void BreakDue_FiresOnce()
    {
        var timer = new TimerStateMachine();
        var count = 0;
        timer.OnBreakDue += () => count++;
        timer.Tick(FlowState.Normal, 1200);
        timer.Tick(FlowState.Normal, 1);
        Assert.Equal(1, count);
    }

    [Fact]
    public void PausesDuringIdle()
    {
        var timer = new TimerStateMachine();
        timer.Tick(FlowState.Normal, 600);
        var remaining = timer.RemainingSeconds;
        timer.Tick(FlowState.Idle, 120);
        Assert.Equal(remaining, timer.RemainingSeconds);
        Assert.True(timer.IsPaused);
    }

    [Fact]
    public void PausesDuringMeeting()
    {
        var timer = new TimerStateMachine();
        timer.Tick(FlowState.Normal, 600);
        var remaining = timer.RemainingSeconds;
        timer.Tick(FlowState.Meeting, 120);
        Assert.Equal(remaining, timer.RemainingSeconds);
    }

    [Fact]
    public void NoFlowScaling()
    {
        var timer = new TimerStateMachine();
        timer.Tick(FlowState.Normal, 600);
        Assert.Equal(600, timer.RemainingSeconds);

        // Flow state no longer changes duration — BreakDecisionEngine handles extensions
        timer.Tick(FlowState.Flow, 0);
        Assert.Equal(600, timer.RemainingSeconds);
    }

    [Fact]
    public void ResetAfterBreak()
    {
        var timer = new TimerStateMachine();
        timer.Tick(FlowState.Normal, 1000);
        timer.ResetAfterBreak();
        Assert.Equal(1200, timer.RemainingSeconds);
        Assert.False(timer.IsPaused);
    }

    [Fact]
    public void TimerNeverNegative()
    {
        var timer = new TimerStateMachine();
        timer.Tick(FlowState.Normal, 9999);
        Assert.Equal(0, timer.RemainingSeconds);
        Assert.Equal(1.0, timer.Progress);
    }

    [Fact]
    public void ProgressAlways_0_to_1()
    {
        var timer = new TimerStateMachine();
        Assert.InRange(timer.Progress, 0, 1);
        timer.Tick(FlowState.Normal, 600);
        Assert.InRange(timer.Progress, 0, 1);
        timer.Tick(FlowState.Normal, 9999);
        Assert.InRange(timer.Progress, 0, 1);
    }

    [Fact]
    public void Reset_ToCustomDuration_UpdatesBothRemainingAndTimerDuration()
    {
        // Reset(duration) now sets both RemainingSeconds and TimerDuration to
        // the new value. Previously TimerDuration was hard-coded to 1200, which
        // made Progress report "50% done" at the start of a 10-minute
        // extension. Fixed in the same commit that adds this test.
        var timer = new TimerStateMachine();
        timer.Reset(600);
        Assert.Equal(600, timer.RemainingSeconds);
        Assert.Equal(600, timer.TimerDuration);
        Assert.Equal(0.0, timer.Progress);
        Assert.False(timer.IsPaused);
    }

    [Fact]
    public void Reset_ProgressStartsAtZero()
    {
        // Direct regression test for the bug — make sure a fresh extension
        // shows 0% progress, not (1 - 600/1200) = 50%.
        var timer = new TimerStateMachine();
        timer.Tick(FlowState.Normal, 300); // burn 5 min of the original 20
        Assert.True(timer.Progress > 0);

        timer.Reset(600); // extension to 10 min
        Assert.Equal(0.0, timer.Progress);
    }

    [Fact]
    public void ResetAfterBreak_RestoresDefault20Min()
    {
        var timer = new TimerStateMachine();
        timer.Reset(300);
        Assert.Equal(300, timer.RemainingSeconds);
        timer.ResetAfterBreak();
        Assert.Equal(1200, timer.RemainingSeconds);
        Assert.Equal(1200, timer.TimerDuration);
    }

    [Fact]
    public void OnBreakDue_NotRefired_AfterReset()
    {
        var timer = new TimerStateMachine();
        var count = 0;
        timer.OnBreakDue += () => count++;
        timer.Tick(FlowState.Normal, 1200);
        Assert.Equal(1, count);

        timer.ResetAfterBreak();
        timer.Tick(FlowState.Normal, 1200);
        Assert.Equal(2, count); // a fresh cycle is allowed to fire again
    }

    [Fact]
    public void IsPaused_FalseAfterMeetingEnds()
    {
        var timer = new TimerStateMachine();
        timer.Tick(FlowState.Meeting, 1);
        Assert.True(timer.IsPaused);
        timer.Tick(FlowState.Normal, 1);
        Assert.False(timer.IsPaused);
    }

    [Fact]
    public void TimerDuration_NeverChanges_DuringNormalCountdown()
    {
        // After the BlinkCore refactor, duration is fixed at 20 min — flow doesn't
        // extend it through the timer; BreakDecisionEngine handles extensions.
        var timer = new TimerStateMachine();
        Assert.Equal(1200, timer.TimerDuration);
        timer.Tick(FlowState.Normal, 300);
        Assert.Equal(1200, timer.TimerDuration);
        timer.Tick(FlowState.Flow, 0);
        Assert.Equal(1200, timer.TimerDuration);
    }
}
