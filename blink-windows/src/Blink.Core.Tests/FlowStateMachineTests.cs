using Blink.Core.FlowDetection;

namespace Blink.Core.Tests;

public class FlowStateMachineTests
{
    [Fact] public void StartsInNormal() =>
        Assert.Equal(FlowState.Normal, new FlowStateMachine().State);

    [Fact]
    public void HighScoreFor3Min_TransitionsToFlow()
    {
        var sm = new FlowStateMachine();
        for (int i = 0; i < 8; i++)
            sm.Tick(0.8, 0, false, false, 1000 + i * 30);
        Assert.Equal(FlowState.Flow, sm.State);
    }

    [Fact]
    public void FlowHysteresis_SingleLowTick_StaysInFlow()
    {
        var sm = new FlowStateMachine();
        for (int i = 0; i < 8; i++)
            sm.Tick(0.8, 0, false, false, 1000 + i * 30);
        Assert.Equal(FlowState.Flow, sm.State);

        sm.Tick(0.3, 0, false, false, 1270);
        Assert.Equal(FlowState.Flow, sm.State);
    }

    [Fact]
    public void GapExceedingTolerance_ExitsFlow()
    {
        var sm = new FlowStateMachine();
        // Enter flow (3+ min of activity)
        for (int i = 0; i < 8; i++)
            sm.Tick(0.0, 5, false, false, 1000 + i * 30);
        Assert.Equal(FlowState.Flow, sm.State);

        // Gap > tolerance (65s > 60s at default 0.7 sensitivity)
        sm.Tick(0.0, 65, false, false, 1300);
        Assert.Equal(FlowState.Normal, sm.State);
    }

    [Fact]
    public void IdleDetection_At180s()
    {
        var sm = new FlowStateMachine();
        sm.Tick(0.5, 25, false, false, 1000);
        Assert.Equal(FlowState.Normal, sm.State); // 25s not enough

        sm.Tick(0.5, 185, false, false, 1030);
        Assert.Equal(FlowState.Idle, sm.State);
    }

    [Fact]
    public void MeetingDetection()
    {
        var sm = new FlowStateMachine();
        sm.Tick(0.5, 0, true, false, 1000);
        Assert.Equal(FlowState.Meeting, sm.State);
    }

    [Fact]
    public void ReturnsToNormalAfterIdle_FlowMustBeReEarned()
    {
        var sm = new FlowStateMachine();
        for (int i = 0; i < 8; i++)
            sm.Tick(0.8, 0, false, false, 1000 + i * 30);
        Assert.Equal(FlowState.Flow, sm.State);

        sm.Tick(0.8, 185, false, false, 1300);
        Assert.Equal(FlowState.Idle, sm.State);

        sm.Tick(0.8, 0, false, false, 1330);
        Assert.Equal(FlowState.Normal, sm.State); // NOT flow
    }

    [Fact]
    public void DeepFlow_After15Min()
    {
        var sm = new FlowStateMachine();
        for (int i = 0; i < 40; i++)
            sm.Tick(0.8, 0, false, false, 1000 + i * 30);
        Assert.Equal(FlowState.DeepFlow, sm.State);
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

    [Fact]
    public void ExitBreak_ResetsHysteresis()
    {
        var sm = new FlowStateMachine();
        for (int i = 0; i < 8; i++)
            sm.Tick(0.8, 0, false, false, 1000 + i * 30);
        Assert.Equal(FlowState.Flow, sm.State);

        sm.EnterBreakPrompted();
        sm.ExitBreakPrompted();
        Assert.Equal(FlowState.Normal, sm.State);

        // One high tick should NOT immediately re-enter flow
        sm.Tick(0.9, 0, false, false, 1300);
        Assert.Equal(FlowState.Normal, sm.State);
    }

    [Fact]
    public void MeetingTakesPriorityOverIdle()
    {
        var sm = new FlowStateMachine();
        sm.Tick(0.5, 200, true, false, 1000);
        Assert.Equal(FlowState.Meeting, sm.State);
    }
}
