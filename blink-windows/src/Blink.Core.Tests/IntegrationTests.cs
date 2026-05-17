using Blink.Core.FlowDetection;

namespace Blink.Core.Tests;

public class IntegrationTests
{
    [Fact]
    public void BriefPause_DoesNotTriggerIdle()
    {
        var sm = new FlowStateMachine();
        sm.Tick(0.5, 30, false, false, 1000);
        Assert.Equal(FlowState.Normal, sm.State);
    }

    [Fact]
    public void WalkingAway_TriggersIdle()
    {
        var sm = new FlowStateMachine();
        sm.Tick(0.5, 185, false, false, 1000);
        Assert.Equal(FlowState.Idle, sm.State);
    }

    [Fact]
    public void IdleDoesNotFlap()
    {
        var sm = new FlowStateMachine();
        sm.Tick(0.5, 0, false, false, 1000);
        Assert.Equal(FlowState.Normal, sm.State);

        sm.Tick(0.5, 25, false, false, 1030);
        Assert.Equal(FlowState.Normal, sm.State);

        sm.Tick(0.5, 0, false, false, 1060);
        Assert.Equal(FlowState.Normal, sm.State);

        sm.Tick(0.5, 35, false, false, 1090);
        Assert.Equal(FlowState.Normal, sm.State);
    }

    [Fact]
    public void IdleResetsToNormal()
    {
        var sm = new FlowStateMachine();
        for (int i = 0; i < 8; i++)
            sm.Tick(0.8, 0, false, false, 1000 + i * 30);
        Assert.Equal(FlowState.Normal, sm.State); // no flow detection

        sm.Tick(0.8, 185, false, false, 1360);
        Assert.Equal(FlowState.Idle, sm.State);

        sm.Tick(0.8, 0, false, false, 1390);
        Assert.Equal(FlowState.Normal, sm.State);
    }

    [Fact]
    public void ContinuousActivityStaysNormal()
    {
        var sm = new FlowStateMachine();
        for (int i = 0; i < 40; i++)
            sm.Tick(0.85, 0, false, false, 1000 + i * 30);
        Assert.Equal(FlowState.Normal, sm.State); // no flow/deepFlow
    }

    [Fact]
    public void AgentWorkflow_SittingStill_TriggersIdle()
    {
        var sm = new FlowStateMachine();
        sm.Tick(0.3, 185, false, false, 1000);
        Assert.Equal(FlowState.Idle, sm.State);
    }

    [Fact]
    public void MeetingReturnsToNormal()
    {
        var sm = new FlowStateMachine();
        for (int i = 0; i < 8; i++)
            sm.Tick(0.8, 0, false, false, 1000 + i * 30);
        Assert.Equal(FlowState.Normal, sm.State);

        sm.Tick(0.8, 0, true, false, 1300);
        Assert.Equal(FlowState.Meeting, sm.State);

        sm.Tick(0.5, 0, false, false, 1600);
        Assert.Equal(FlowState.Normal, sm.State);
    }
}
