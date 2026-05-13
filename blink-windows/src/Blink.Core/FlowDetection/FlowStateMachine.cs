namespace Blink.Core.FlowDetection;

/// <summary>
/// Manages flow state transitions based on activity gaps.
/// Flow is determined by a single metric: how long since the last input?
/// The sensitivity slider controls gap tolerance (how long you can pause and stay in flow).
/// </summary>
public sealed class FlowStateMachine
{
    public FlowState State { get; private set; } = FlowState.Normal;
    public event Action<FlowState, FlowState>? OnStateChange;

    // Threshold defaults
    public const double DefaultFlowEntryThreshold = 0.7;  // sensitivity
    public const double DefaultFlowExitThreshold = 0.4;
    public const double DefaultFlowEntryDuration = 180;    // 3 minutes of activity
    public const double DefaultFlowExitDuration = 120;
    public const double DefaultDeepFlowDuration = 900;     // 15 minutes in flow
    public const double DefaultIdleThreshold = 180;        // 3 min idle = away

    // Configurable thresholds
    public double FlowEntryThreshold { get; set; } = DefaultFlowEntryThreshold;
    public double FlowExitThreshold { get; set; } = DefaultFlowExitThreshold;
    public double FlowEntryDuration { get; set; } = DefaultFlowEntryDuration;
    public double FlowExitDuration { get; set; } = DefaultFlowExitDuration;
    public double DeepFlowDuration { get; set; } = DefaultDeepFlowDuration;
    public double IdleThreshold { get; set; } = DefaultIdleThreshold;

    // Activity tracking
    private double? _continuousActivityStart;
    private double? _flowEntrySince;
    private FlowState? _stateBeforePause;

    /// Gap tolerance in seconds, derived from sensitivity (0.4–0.9).
    /// Higher sensitivity = longer tolerance = easier to stay in flow.
    public double GapTolerance
    {
        get
        {
            var t = (FlowEntryThreshold - 0.4) / (0.9 - 0.4);
            return 15 + t * 75;
        }
    }

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

        // Idle detection (walked away)
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
            _continuousActivityStart = null;
            _flowEntrySince = null;
            Transition(FlowState.Normal);
        }

        // Skip flow calculations during break
        if (State == FlowState.BreakPrompted) return;

        // Activity-gap based flow detection
        var isActive = secondsSinceLastInput < GapTolerance;

        if (isActive)
        {
            _continuousActivityStart ??= now;
        }
        else
        {
            _continuousActivityStart = null;
        }

        switch (State)
        {
            case FlowState.Normal:
                if (_continuousActivityStart is { } start && now - start >= FlowEntryDuration)
                {
                    _flowEntrySince = now;
                    Transition(FlowState.Flow);
                }
                break;

            case FlowState.Flow:
                if (!isActive)
                {
                    _flowEntrySince = null;
                    _continuousActivityStart = null;
                    Transition(FlowState.Normal);
                }
                else if (_flowEntrySince is { } flowStart && now - flowStart >= DeepFlowDuration)
                {
                    Transition(FlowState.DeepFlow);
                }
                break;

            case FlowState.DeepFlow:
                if (!isActive)
                {
                    _flowEntrySince = null;
                    _continuousActivityStart = null;
                    Transition(FlowState.Normal);
                }
                break;
        }
    }

    public void EnterBreakPrompted() => Transition(FlowState.BreakPrompted);

    public void ExitBreakPrompted()
    {
        _flowEntrySince = null;
        _continuousActivityStart = null;
        Transition(FlowState.Normal);
    }

    private void Transition(FlowState newState)
    {
        if (newState == State) return;
        var old = State;
        State = newState;
        OnStateChange?.Invoke(old, newState);
    }
}
