using Blink.Core.FlowDetection;

namespace Blink.Core.Compliance;

public sealed class BreakComplianceTracker
{
    public event Action<BreakRecord>? OnBreakRecorded;
    public bool IsTrackingBreak => _promptTime.HasValue;

    private DateTime? _promptTime;
    private FlowState? _promptFlowState;
    private double? _promptFlowScore;

    public void BreakPrompted(DateTime time, FlowState flowState, double flowScore)
    {
        _promptTime = time;
        _promptFlowState = flowState;
        _promptFlowScore = flowScore;
    }

    public void BreakDismissed(DateTime time)
    {
        if (_promptTime is not { } promptTime || _promptFlowState is not { } flowState || _promptFlowScore is not { } score)
            return;

        var elapsed = (time - promptTime).TotalSeconds;
        var compliance = elapsed < 5 ? BreakCompliance.Dismissed : BreakCompliance.Delayed;

        var record = new BreakRecord(promptTime, time, flowState, score, compliance, null);
        OnBreakRecorded?.Invoke(record);
        Reset();
    }

    public void BreakTaken(DateTime time, double idleDuration)
    {
        if (_promptTime is not { } promptTime || _promptFlowState is not { } flowState || _promptFlowScore is not { } score)
            return;

        var elapsed = (time - promptTime).TotalSeconds;
        var compliance = elapsed <= 60 ? BreakCompliance.Taken : BreakCompliance.Delayed;

        var record = new BreakRecord(promptTime, time, flowState, score, compliance, idleDuration);
        OnBreakRecorded?.Invoke(record);
        Reset();
    }

    public void BreakIgnored(DateTime time)
    {
        if (_promptTime is not { } promptTime || _promptFlowState is not { } flowState || _promptFlowScore is not { } score)
            return;

        var record = new BreakRecord(promptTime, null, flowState, score, BreakCompliance.Ignored, null);
        OnBreakRecorded?.Invoke(record);
        Reset();
    }

    private void Reset()
    {
        _promptTime = null;
        _promptFlowState = null;
        _promptFlowScore = null;
    }
}
