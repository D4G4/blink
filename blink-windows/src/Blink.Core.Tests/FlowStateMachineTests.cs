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

    // --- Idle boundary cases ---

    [Fact]
    public void Idle_AtExactly180s_TriggersIdle()
    {
        var sm = new FlowStateMachine();
        sm.Tick(0, 180, false, false, 1000);
        Assert.Equal(FlowState.Idle, sm.State);
    }

    [Fact]
    public void Idle_Just_Below_180s_StaysNormal()
    {
        var sm = new FlowStateMachine();
        sm.Tick(0, 179.9, false, false, 1000);
        Assert.Equal(FlowState.Normal, sm.State);
    }

    // --- Meeting via camera only ---

    [Fact]
    public void CameraOnly_TriggersMeeting()
    {
        var sm = new FlowStateMachine();
        sm.Tick(0, 0, false, true, 1000);
        Assert.Equal(FlowState.Meeting, sm.State);
    }

    [Fact]
    public void MicAndCamera_BothActive_StaysInMeeting()
    {
        var sm = new FlowStateMachine();
        sm.Tick(0, 0, true, true, 1000);
        Assert.Equal(FlowState.Meeting, sm.State);

        sm.Tick(0, 0, false, true, 1030);
        Assert.Equal(FlowState.Meeting, sm.State);

        sm.Tick(0, 0, true, false, 1060);
        Assert.Equal(FlowState.Meeting, sm.State);

        sm.Tick(0, 0, false, false, 1090);
        Assert.Equal(FlowState.Normal, sm.State);
    }

    // --- Idle wins over meeting? Spec lockdown ---

    [Fact]
    public void Idle_During_Meeting_StaysInMeeting()
    {
        // User has mic on but isn't typing — they're still in the meeting,
        // so we don't pretend they walked away.
        var sm = new FlowStateMachine();
        sm.Tick(0, 200, true, false, 1000);
        Assert.Equal(FlowState.Meeting, sm.State);
    }

    // --- State doesn't change unexpectedly ---

    [Fact]
    public void RepeatedTicks_WithSameInputs_AreIdempotent()
    {
        var sm = new FlowStateMachine();
        sm.Tick(0, 200, false, false, 1000);
        Assert.Equal(FlowState.Idle, sm.State);
        for (var i = 0; i < 10; i++)
            sm.Tick(0, 200, false, false, 1000 + i);
        Assert.Equal(FlowState.Idle, sm.State);
    }
}
