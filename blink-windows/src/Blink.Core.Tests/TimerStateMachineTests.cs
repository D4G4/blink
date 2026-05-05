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
    public void AdjustsProportionallyForFlow()
    {
        var timer = new TimerStateMachine();
        timer.Tick(FlowState.Normal, 600); // 50% elapsed
        Assert.Equal(600, timer.RemainingSeconds);

        timer.Tick(FlowState.Flow, 0); // 30min * 50% remaining = 900
        Assert.Equal(900, timer.RemainingSeconds);
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
}
