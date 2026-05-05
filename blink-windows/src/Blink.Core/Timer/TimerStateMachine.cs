using Blink.Core.FlowDetection;

namespace Blink.Core.Timer;

public sealed class TimerStateMachine
{
    public const double DefaultNormalDuration = 1200;    // 20 minutes
    public const double DefaultFlowDuration = 1800;      // 30 minutes
    public const double DefaultDeepFlowDuration = 2400;  // 40 minutes

    public double RemainingSeconds { get; private set; }
    public bool IsPaused { get; private set; }
    public event Action? OnBreakDue;

    public double NormalDuration { get; set; } = DefaultNormalDuration;
    public double FlowDuration { get; set; } = DefaultFlowDuration;
    public double DeepFlowDuration { get; set; } = DefaultDeepFlowDuration;

    private FlowState _currentFlowState = FlowState.Normal;

    public TimerStateMachine()
    {
        RemainingSeconds = DefaultNormalDuration;
    }

    public double TimerDuration => Duration(_currentFlowState);

    public double Progress
    {
        get
        {
            var total = TimerDuration;
            return total > 0 ? Math.Max(0, Math.Min(1.0, 1.0 - RemainingSeconds / total)) : 1.0;
        }
    }

    public void Tick(FlowState flowState, double deltaSeconds)
    {
        // Pause during idle or meeting
        if (flowState is FlowState.Idle or FlowState.Meeting)
        {
            IsPaused = true;
            return;
        }

        // If flow state changed, adjust remaining time proportionally
        if (flowState != _currentFlowState && flowState != FlowState.BreakPrompted)
        {
            var oldDuration = Duration(_currentFlowState);
            var newDuration = Duration(flowState);

            if (oldDuration > 0)
            {
                var elapsed = oldDuration - RemainingSeconds;
                var elapsedRatio = elapsed / oldDuration;
                RemainingSeconds = newDuration * (1.0 - elapsedRatio);
            }

            _currentFlowState = flowState;
        }

        IsPaused = false;

        if (flowState == FlowState.BreakPrompted) return;

        if (RemainingSeconds <= 0) return;

        RemainingSeconds -= deltaSeconds;

        if (RemainingSeconds <= 0)
        {
            RemainingSeconds = 0;
            OnBreakDue?.Invoke();
        }
    }

    public void ResetAfterBreak()
    {
        _currentFlowState = FlowState.Normal;
        RemainingSeconds = NormalDuration;
        IsPaused = false;
    }

    public void Reset(double duration)
    {
        RemainingSeconds = duration;
        IsPaused = false;
    }

    public void Pause() => IsPaused = true;
    public void Resume() => IsPaused = false;

    private double Duration(FlowState state) => state switch
    {
        FlowState.Flow => FlowDuration,
        FlowState.DeepFlow => DeepFlowDuration,
        _ => NormalDuration
    };
}
