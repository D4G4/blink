using Blink.Core.Compliance;
using Blink.Core.FlowDetection;

namespace Blink.Core.Tests;

public class BreakComplianceTrackerTests
{
    [Fact]
    public void BreakTaken_Within60s()
    {
        var tracker = new BreakComplianceTracker();
        BreakRecord? recorded = null;
        tracker.OnBreakRecorded += r => recorded = r;

        var prompt = DateTime.Now;
        tracker.BreakPrompted(prompt, FlowState.Normal, 0.5);
        tracker.BreakTaken(prompt.AddSeconds(10), 20);

        Assert.NotNull(recorded);
        Assert.Equal(BreakCompliance.Taken, recorded.Compliance);
    }

    [Fact]
    public void BreakDismissed_Quickly()
    {
        var tracker = new BreakComplianceTracker();
        BreakRecord? recorded = null;
        tracker.OnBreakRecorded += r => recorded = r;

        var prompt = DateTime.Now;
        tracker.BreakPrompted(prompt, FlowState.Normal, 0.5);
        tracker.BreakDismissed(prompt.AddSeconds(2));

        Assert.Equal(BreakCompliance.Dismissed, recorded!.Compliance);
    }

    [Fact]
    public void BreakDismissed_AfterDelay()
    {
        var tracker = new BreakComplianceTracker();
        BreakRecord? recorded = null;
        tracker.OnBreakRecorded += r => recorded = r;

        var prompt = DateTime.Now;
        tracker.BreakPrompted(prompt, FlowState.Flow, 0.8);
        tracker.BreakDismissed(prompt.AddSeconds(30));

        Assert.Equal(BreakCompliance.Delayed, recorded!.Compliance);
    }

    [Fact]
    public void BreakIgnored()
    {
        var tracker = new BreakComplianceTracker();
        BreakRecord? recorded = null;
        tracker.OnBreakRecorded += r => recorded = r;

        var prompt = DateTime.Now;
        tracker.BreakPrompted(prompt, FlowState.Normal, 0.3);
        tracker.BreakIgnored(prompt.AddSeconds(300));

        Assert.Equal(BreakCompliance.Ignored, recorded!.Compliance);
        Assert.Null(recorded.RespondedAt);
    }

    [Fact]
    public void NoPrompt_NoRecord()
    {
        var tracker = new BreakComplianceTracker();
        BreakRecord? recorded = null;
        tracker.OnBreakRecorded += r => recorded = r;

        tracker.BreakTaken(DateTime.Now, 20);
        Assert.Null(recorded);
    }

    [Fact]
    public void IsTrackingBreak_ReflectsState()
    {
        var tracker = new BreakComplianceTracker();
        Assert.False(tracker.IsTrackingBreak);

        tracker.BreakPrompted(DateTime.Now, FlowState.Normal, 0.5);
        Assert.True(tracker.IsTrackingBreak);

        tracker.BreakTaken(DateTime.Now, 20);
        Assert.False(tracker.IsTrackingBreak);
    }

    [Fact]
    public void CapturesPromptState()
    {
        var tracker = new BreakComplianceTracker();
        BreakRecord? recorded = null;
        tracker.OnBreakRecorded += r => recorded = r;

        tracker.BreakPrompted(DateTime.Now, FlowState.DeepFlow, 0.92);
        tracker.BreakTaken(DateTime.Now, 20);

        Assert.Equal(FlowState.DeepFlow, recorded!.FlowStateWhenPrompted);
        Assert.Equal(0.92, recorded.FlowScore);
    }
}
