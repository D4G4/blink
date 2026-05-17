using Blink.Core.FlowDetection;

namespace Blink.Core.Tests;

public class FlowStateMachineTests
{
    [Fact]
    public void StartsInNormalState()
    {
        var sm = new FlowStateMachine();
        Assert.Equal(FlowState.Normal, sm.State);
    }

    [Fact]
    public void IdleAfter180Seconds()
    {
        var sm = new FlowStateMachine();
        sm.Tick(0, 185, false, false, 1000);
        Assert.Equal(FlowState.Idle, sm.State);
    }

    [Fact]
    public void ReturnsToNormalAfterIdle()
    {
        var sm = new FlowStateMachine();
        sm.Tick(0, 185, false, false, 1000);
        Assert.Equal(FlowState.Idle, sm.State);
        sm.Tick(0, 0, false, false, 1030);
        Assert.Equal(FlowState.Normal, sm.State);
    }

    [Fact]
    public void MeetingWhenMicActive()
    {
        var sm = new FlowStateMachine();
        sm.Tick(0, 0, true, false, 1000);
        Assert.Equal(FlowState.Meeting, sm.State);
    }

    [Fact]
    public void ReturnsToNormalAfterMeeting()
    {
        var sm = new FlowStateMachine();
        sm.Tick(0, 0, true, false, 1000);
        Assert.Equal(FlowState.Meeting, sm.State);
        sm.Tick(0, 0, false, false, 1030);
        Assert.Equal(FlowState.Normal, sm.State);
    }

    [Fact]
    public void ContinuousActivityStaysNormal()
    {
        var sm = new FlowStateMachine();
        for (int i = 0; i < 40; i++)
            sm.Tick(0.8, 3, false, false, 1000 + i * 30);
        Assert.Equal(FlowState.Normal, sm.State);
    }

    [Fact]
    public void BreakPromptedAndExit()
    {
        var sm = new FlowStateMachine();
        sm.EnterBreakPrompted();
        Assert.Equal(FlowState.BreakPrompted, sm.State);
        sm.ExitBreakPrompted();
        Assert.Equal(FlowState.Normal, sm.State);
    }
}
