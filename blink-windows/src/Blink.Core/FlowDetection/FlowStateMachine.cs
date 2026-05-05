namespace Blink.Core.FlowDetection;

public sealed class FlowStateMachine
{
    public FlowState State { get; private set; } = FlowState.Normal;
    public event Action<FlowState, FlowState>? OnStateChange;

    // Threshold defaults
    public const double DefaultFlowEntryThreshold = 0.7;
    public const double DefaultFlowExitThreshold = 0.4;
    public const double DefaultFlowEntryDuration = 180;    // 3 minutes
    public const double DefaultFlowExitDuration = 120;     // 2 minutes
    public const double DefaultDeepFlowDuration = 900;     // 15 minutes
    public const double DefaultIdleThreshold = 90;         // 90 seconds

    // Configurable thresholds
    public double FlowEntryThreshold { get; set; } = DefaultFlowEntryThreshold;
    public double FlowExitThreshold { get; set; } = DefaultFlowExitThreshold;
    public double FlowEntryDuration { get; set; } = DefaultFlowEntryDuration;
    public double FlowExitDuration { get; set; } = DefaultFlowExitDuration;
    public double DeepFlowDuration { get; set; } = DefaultDeepFlowDuration;
    public double IdleThreshold { get; set; } = DefaultIdleThreshold;

    // Hysteresis tracking
    private double? _scoreAboveFlowThresholdSince;
    private double? _scoreBelowExitThresholdSince;
    private double? _flowEntrySince;
    private FlowState? _stateBeforePause;

    public void Tick(double flowScore, double secondsSinceLastInput, bool isMicActive, bool isCameraActive, double now)
    {
        // Meeting detection takes priority
        if (isMicActive || isCameraActive)
        {
            if (State != FlowState.Meeting)
            {
                _stateBeforePause = State;
                Transition(FlowState.Meeting);
            }
            return;
        }

        // Idle detection
        if (secondsSinceLastInput >= IdleThreshold)
        {
            if (State != FlowState.Idle)
            {
                _stateBeforePause = State;
                Transition(FlowState.Idle);
            }
            return;
        }

        // Returning from idle/meeting
        if (State is FlowState.Idle or FlowState.Meeting)
        {
            _stateBeforePause = null;
            _scoreAboveFlowThresholdSince = null;
            _scoreBelowExitThresholdSince = null;
            _flowEntrySince = null;
            Transition(FlowState.Normal);
        }

        // Skip flow calculations during break
        if (State == FlowState.BreakPrompted) return;

        UpdateHysteresis(flowScore, now);

        switch (State)
        {
            case FlowState.Normal:
                if (_scoreAboveFlowThresholdSince is { } since && now - since >= FlowEntryDuration)
                {
                    _flowEntrySince = now;
                    Transition(FlowState.Flow);
                }
                break;

            case FlowState.Flow:
                if (_scoreBelowExitThresholdSince is { } exitSince && now - exitSince >= FlowExitDuration)
                {
                    _flowEntrySince = null;
                    Transition(FlowState.Normal);
                }
                else if (_flowEntrySince is { } flowStart && now - flowStart >= DeepFlowDuration)
                {
                    Transition(FlowState.DeepFlow);
                }
                break;

            case FlowState.DeepFlow:
                if (_scoreBelowExitThresholdSince is { } deepExitSince && now - deepExitSince >= FlowExitDuration)
                {
                    _flowEntrySince = null;
                    Transition(FlowState.Normal);
                }
                break;
        }
    }

    public void EnterBreakPrompted() => Transition(FlowState.BreakPrompted);

    public void ExitBreakPrompted()
    {
        _flowEntrySince = null;
        _scoreAboveFlowThresholdSince = null;
        _scoreBelowExitThresholdSince = null;
        Transition(FlowState.Normal);
    }

    private void UpdateHysteresis(double flowScore, double now)
    {
        if (flowScore >= FlowEntryThreshold)
        {
            _scoreAboveFlowThresholdSince ??= now;
            _scoreBelowExitThresholdSince = null;
        }
        else if (flowScore < FlowExitThreshold)
        {
            _scoreBelowExitThresholdSince ??= now;
            _scoreAboveFlowThresholdSince = null;
        }
        else
        {
            if (State == FlowState.Normal)
                _scoreBelowExitThresholdSince = null;
            else
                _scoreAboveFlowThresholdSince = null;
        }
    }

    private void Transition(FlowState newState)
    {
        if (newState == State) return;
        var old = State;
        State = newState;
        OnStateChange?.Invoke(old, newState);
    }
}
