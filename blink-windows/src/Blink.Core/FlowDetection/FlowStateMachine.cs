namespace Blink.Core.FlowDetection;

/// <summary>
/// Detects idle and meeting states to pause the timer.
/// Flow/deep flow are NOT tracked — BreakDecisionEngine handles that at timer end.
/// </summary>
public sealed class FlowStateMachine
{
    public FlowState State { get; private set; } = FlowState.Normal;
    public event Action<FlowState, FlowState>? OnStateChange;

    public double IdleThreshold { get; set; } = 180; // 3 min idle = away

    public void Tick(double flowScore, double secondsSinceLastInput, bool isMicActive, bool isCameraActive, double now)
    {
        if (isMicActive || isCameraActive)
        {
            if (State != FlowState.Meeting)
                Transition(FlowState.Meeting);
            return;
        }

        if (secondsSinceLastInput >= IdleThreshold)
        {
            if (State != FlowState.Idle)
                Transition(FlowState.Idle);
            return;
        }

        if (State is FlowState.Idle or FlowState.Meeting)
            Transition(FlowState.Normal);
    }

    public void EnterBreakPrompted() => Transition(FlowState.BreakPrompted);

    public void ExitBreakPrompted() => Transition(FlowState.Normal);

    private void Transition(FlowState newState)
    {
        if (newState == State) return;
        var old = State;
        State = newState;
        OnStateChange?.Invoke(old, newState);
    }
}
