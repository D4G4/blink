using Blink.Core.FlowDetection;

namespace Blink.Core.Timer;

/// <summary>
/// 20-minute countdown timer. Pauses during idle/meeting.
/// </summary>
public sealed class TimerStateMachine
{
    public const double DefaultDuration = 1200; // 20 minutes

    public double RemainingSeconds { get; private set; } = DefaultDuration;
    public bool IsPaused { get; private set; }
    public event Action? OnBreakDue;

    // Tracks the duration of the *current* cycle. Set by Reset(duration) so
    // that the UI's progress bar starts at 0% when an extension begins.
    public double TimerDuration { get; private set; } = DefaultDuration;

    public double Progress
    {
        get
        {
            return TimerDuration > 0
                ? Math.Max(0, Math.Min(1.0, 1.0 - RemainingSeconds / TimerDuration))
                : 1.0;
        }
    }

    public void Tick(FlowState flowState, double deltaSeconds)
    {
        if (flowState is FlowState.Idle or FlowState.Meeting)
        {
            IsPaused = true;
            return;
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
        RemainingSeconds = DefaultDuration;
        TimerDuration = DefaultDuration;
        IsPaused = false;
    }

    public void Reset(double duration)
    {
        RemainingSeconds = duration;
        TimerDuration = duration;
        IsPaused = false;
    }
}
