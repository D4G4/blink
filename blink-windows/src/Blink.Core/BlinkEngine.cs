using Blink.Core.Compliance;
using Blink.Core.FlowDetection;
using Blink.Core.Timer;

namespace Blink.Core;

/// <summary>
/// Central orchestrator for Blink's break reminder logic.
/// Receives input events and a 1-second tick from the platform layer.
/// Produces callbacks when the UI needs to show a break, toast, or update.
/// Port of Swift BlinkCore.BlinkEngine.
/// </summary>
public sealed class BlinkEngine
{
    // Callbacks
    public Action<int>? OnShowBreak;              // breakNumber
    public Action<string>? OnShowExtendToast;     // reason
    public Action<double, double>? OnTimerUpdate; // remaining, total
    public Action<DisplayState>? OnStateChange;

    public enum DisplayState { Working, Away, Meeting, OnBreak }

    // Config
    /// <summary>
    /// User's sensitivity setting (0.4–0.9). Required at construction —
    /// BlinkCore has no default; the canonical default lives in the consumer.
    /// </summary>
    public double Sensitivity
    {
        get => _sensitivity;
        set
        {
            _sensitivity = value;
            _config = FlowConfig.ForSensitivity(value);
            _decisionEngine.Sensitivity = value;
        }
    }
    private double _sensitivity;

    /// <summary>
    /// Wall-clock cap: force a break after this many seconds since the last
    /// break, regardless of idle pauses or extensions. Default 40 min.
    /// </summary>
    public double MaxWallClockSeconds { get; set; } = 2400;

    // Sub-engines
    private readonly TimerStateMachine _timer = new();
    private readonly FlowStateMachine _stateMachine = new();
    private readonly BreakDecisionEngine _decisionEngine;
    private readonly BreakComplianceTracker _complianceTracker = new();
    private FlowConfig _config;

    /// <summary>Decision engine — exposed for spot-check / tests.</summary>
    public BreakDecisionEngine DecisionEngine => _decisionEngine;

    // Activity timestamps (nullable — set on first event)
    private DateTime? _lastKeystrokeTime;
    private DateTime? _lastClickTime;
    private DateTime? _lastScrollTime;
    private DateTime? _lastAppSwitchTime;

    private DateTime LastActivityTime =>
        new[] { _lastKeystrokeTime, _lastClickTime, _lastScrollTime, _lastAppSwitchTime }
            .Where(t => t.HasValue)
            .Select(t => t!.Value)
            .DefaultIfEmpty(_engineStartTime ?? Now)
            .Max();

    // State
    private bool _breakPending;
    private DateTime? _breakPendingSince;
    private int _consecutiveBreaks;
    private DateTime? _lastBreakEndedAt;
    private DateTime? _engineStartTime;
    private bool _isOnBreak;
    private bool _micActive;
    private bool _cameraActive;
    private bool _videoPlaying;

    // Constants
    private const double GraceSeconds = 20;
    private const double IdleThreshold = 180;
    private const double CourtesyWaitMax = 10;
    private const double CourtesyGap = 3;

    /// <summary>
    /// Simulated clock for testing. When set, all time reads use this instead
    /// of DateTime.UtcNow.
    /// </summary>
    public DateTime? SimulatedNow { get; set; }

    private DateTime Now => SimulatedNow ?? DateTime.UtcNow;

    private static double ToUnix(DateTime t) =>
        ((DateTimeOffset)t).ToUnixTimeMilliseconds() / 1000.0;

    public BlinkEngine(double sensitivity)
    {
        _sensitivity = sensitivity;
        _decisionEngine = new BreakDecisionEngine(sensitivity);
        _config = FlowConfig.ForSensitivity(sensitivity);
        _timer.OnBreakDue += HandleBreakDue;
    }

    // MARK: - Input

    public void RecordKeystroke()
    {
        var t = Now;
        _lastKeystrokeTime = t;
        _engineStartTime ??= t;
        _decisionEngine.RecordKeystroke();
    }

    public void RecordClick()
    {
        var t = Now;
        _lastClickTime = t;
        _engineStartTime ??= t;
        _decisionEngine.RecordClick();
    }

    public void RecordScroll()
    {
        var t = Now;
        _lastScrollTime = t;
        _engineStartTime ??= t;
        _decisionEngine.RecordScroll();
    }

    public void RecordAppSwitch(string processName)
    {
        var t = Now;
        _lastAppSwitchTime = t;
        _engineStartTime ??= t;
        _decisionEngine.RecordAppSwitch(processName, ToUnix(t));
    }

    /// <summary>
    /// Seed the currently-frontmost app at session start, without incrementing
    /// the switch counter. Without this, app-switch events only fire on
    /// CHANGES, so a user who launches Blink into a creative app and never
    /// switches produces zero dwell data — silently losing the creative bonus.
    /// </summary>
    public void SetCurrentApp(string processName)
    {
        var t = Now;
        _engineStartTime ??= t;
        _decisionEngine.SetCurrentApp(processName, ToUnix(t));
    }

    public void SetMicActive(bool active)
    {
        if (active && !_micActive)
        {
            // Meeting started → user isn't staring at code. Treat as eye rest.
            _consecutiveBreaks = 0;
            ResetTimerState();
        }
        _micActive = active;
    }

    public void SetCameraActive(bool active) => _cameraActive = active;

    public void SetVideoPlaying(bool playing)
    {
        if (playing != _videoPlaying)
        {
            _videoPlaying = playing;
            if (playing)
            {
                // Video playback = not close-up screen work → treat as eye rest.
                _consecutiveBreaks = 0;
                ResetTimerState();
            }
        }
    }

    public void WakeFromSleep()
    {
        // Sleep means the user wasn't looking at the screen. Treat as eye rest.
        _consecutiveBreaks = 0;
        ResetTimerState();
    }

    // MARK: - Break response

    public void UserTookBreak()
    {
        _consecutiveBreaks++;
        _complianceTracker.BreakTaken(Now, 20);
        ResetTimerState();
        OnStateChange?.Invoke(DisplayState.Working);
    }

    public void UserSkippedBreak()
    {
        _complianceTracker.BreakDismissed(Now);
        ResetTimerState();
        OnStateChange?.Invoke(DisplayState.Working);
    }

    public void UserSnoozed(int minutes)
    {
        _isOnBreak = false;
        _timer.Reset(minutes * 60);
        OnTimerUpdate?.Invoke(_timer.RemainingSeconds, _timer.TimerDuration);
        OnStateChange?.Invoke(DisplayState.Working);
    }

    // MARK: - Tick

    public void Tick()
    {
        var currentTime = Now;
        _engineStartTime ??= currentTime;

        // 1. Pending break delivery (courtesy wait for keyboard gap).
        //    Don't deliver during a meeting — hold pending until mic inactive.
        if (_breakPending)
        {
            if (!_micActive)
            {
                var waited = (currentTime - (_breakPendingSince ?? currentTime)).TotalSeconds;
                var kbIdle = _lastKeystrokeTime.HasValue
                    ? (currentTime - _lastKeystrokeTime.Value).TotalSeconds : 999;
                if (waited >= CourtesyWaitMax || kbIdle >= CourtesyGap)
                {
                    _breakPending = false;
                    _breakPendingSince = null;
                    _isOnBreak = true;
                    _complianceTracker.BreakPrompted(currentTime, FlowState.Normal, 0);
                    OnShowBreak?.Invoke(_consecutiveBreaks + 1);
                    OnStateChange?.Invoke(DisplayState.OnBreak);
                }
            }
            return;
        }

        if (_isOnBreak) return;

        // 2. Grace + idle measurement (grace zeroes idle to prevent flapping).
        var inGrace = _lastBreakEndedAt.HasValue &&
            (currentTime - _lastBreakEndedAt.Value).TotalSeconds < GraceSeconds;
        var currentIdle = inGrace ? 0 : (currentTime - LastActivityTime).TotalSeconds;

        // 3. Tick state machine + publish display state.
        var nowRef = ToUnix(currentTime);
        _stateMachine.Tick(0, currentIdle, _micActive, _cameraActive, nowRef);
        OnStateChange?.Invoke(MapState(_stateMachine.State));

        // 4. Idle reset (eyes already rested). MUST come before the wall-clock
        //    cap — otherwise extended idle (e.g. wake from sleep) trips the cap
        //    before the reset can clear _lastBreakEndedAt, queuing a phantom break.
        if (currentIdle >= IdleThreshold)
        {
            _consecutiveBreaks = 0;
            ResetTimerState();
            return;
        }

        // 5. Wall-clock safety cap — counts active work, skipped during meetings.
        if (!_micActive)
        {
            var sinceLastBreak =
                (currentTime - (_lastBreakEndedAt ?? _engineStartTime ?? currentTime)).TotalSeconds;
            if (sinceLastBreak >= MaxWallClockSeconds)
            {
                _breakPending = true;
                _breakPendingSince = currentTime;
                return;
            }
        }

        // 6. Video playing — already handled in SetVideoPlaying, but skip tick.
        if (_videoPlaying) return;

        // 7. Feed decision engine (tracks window duration).
        _decisionEngine.Tick(nowRef);

        // 8. Tick timer (pauses if idle/meeting).
        var timerState = _stateMachine.State is FlowState.Idle or FlowState.Meeting
            ? _stateMachine.State : FlowState.Normal;
        _timer.Tick(timerState, 1.0);
        OnTimerUpdate?.Invoke(_timer.RemainingSeconds, _timer.TimerDuration);
    }

    // MARK: - Break decision

    private void HandleBreakDue()
    {
        var t = ToUnix(Now);
        var decision = _decisionEngine.Decide(_config.MaxExtensions, t);

        switch (decision)
        {
            case BreakDecision.Extend ext:
                _decisionEngine.ResetWindow(t);
                _timer.Reset(10 * 60);
                OnShowExtendToast?.Invoke(ext.Reason);
                OnTimerUpdate?.Invoke(_timer.RemainingSeconds, _timer.TimerDuration);
                break;

            case BreakDecision.ShowBreak:
                _decisionEngine.ResetWindow(t);
                _breakPending = true;
                _breakPendingSince = Now;
                break;
        }
    }

    /// <summary>
    /// Shared "user just rested" reset. Restarts the wall-clock cap (sets
    /// _lastBreakEndedAt = now) and clears any pending break / on-break state.
    /// Caller owns _consecutiveBreaks and any state-change callback.
    /// </summary>
    private void ResetTimerState()
    {
        _lastBreakEndedAt = Now;
        _breakPending = false;
        _breakPendingSince = null;
        _isOnBreak = false;
        _decisionEngine.ResetAll(ToUnix(Now));
        _timer.ResetAfterBreak();
        OnTimerUpdate?.Invoke(_timer.RemainingSeconds, _timer.TimerDuration);
    }

    private static DisplayState MapState(FlowState state) => state switch
    {
        FlowState.Idle => DisplayState.Away,
        FlowState.Meeting => DisplayState.Meeting,
        FlowState.BreakPrompted => DisplayState.OnBreak,
        _ => DisplayState.Working
    };

    // Public accessors
    public double RemainingSeconds => _timer.RemainingSeconds;
    public double TimerDuration => _timer.TimerDuration;
    public int CurrentBreakStreak => _consecutiveBreaks;
    public DisplayState CurrentState => MapState(_stateMachine.State);
    public BreakComplianceTracker Compliance => _complianceTracker;

    /// <summary>Snapshot of current flow score and signals without affecting state.</summary>
    public BreakDecisionEngine.SpotCheckResult SpotCheckFlow() => _decisionEngine.SpotCheck();
}
