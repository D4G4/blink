using Blink.Core.Compliance;
using Blink.Core.FlowDetection;
using Blink.Core.Timer;

namespace Blink.Core;

/// <summary>
/// Central orchestrator for Blink's break reminder logic.
/// Receives input events and a 1-second tick from the platform layer.
/// Produces callbacks when the UI needs to show a break, toast, or update.
/// Port of Swift BlinkEngine.
/// </summary>
public sealed class BlinkEngine
{
    // Callbacks
    public Action<int>? OnShowBreak;          // breakNumber
    public Action<string>? OnShowExtendToast;  // reason
    public Action<double, double>? OnTimerUpdate; // remaining, total
    public Action<DisplayState>? OnStateChange;

    public enum DisplayState { Working, Away, Meeting, OnBreak }

    // Config
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
    private double _sensitivity = 0.7;

    public double MaxWallClockSeconds { get; set; } = 2400; // 40 min default

    // Sub-engines
    private readonly TimerStateMachine _timer = new();
    private readonly FlowStateMachine _stateMachine = new();
    private readonly BreakDecisionEngine _decisionEngine = new();
    private readonly BreakComplianceTracker _complianceTracker = new();
    private FlowConfig _config;

    // Activity timestamps (nullable — set on first event)
    private DateTime? _lastKeystrokeTime;
    private DateTime? _lastClickTime;
    private DateTime? _lastScrollTime;
    private DateTime? _lastAppSwitchTime;

    private DateTime LastActivityTime =>
        new[] { _lastKeystrokeTime, _lastClickTime, _lastScrollTime, _lastAppSwitchTime }
            .Where(t => t.HasValue)
            .Select(t => t!.Value)
            .DefaultIfEmpty(_engineStartTime ?? DateTime.UtcNow)
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
    private const double GraceSeconds = 60;
    private const double IdleThreshold = 180;
    private const double CourtesyWaitMax = 10;
    private const double CourtesyGap = 3;

    public BlinkEngine()
    {
        _config = FlowConfig.ForSensitivity(_sensitivity);
        _timer.OnBreakDue += HandleBreakDue;
    }

    // MARK: - Input

    public void RecordKeystroke()
    {
        _lastKeystrokeTime = DateTime.UtcNow;
        _engineStartTime ??= _lastKeystrokeTime;
        _decisionEngine.RecordKeystroke();
    }

    public void RecordClick()
    {
        _lastClickTime = DateTime.UtcNow;
        _engineStartTime ??= _lastClickTime;
        _decisionEngine.RecordClick();
    }

    public void RecordScroll()
    {
        _lastScrollTime = DateTime.UtcNow;
        _engineStartTime ??= _lastScrollTime;
        _decisionEngine.RecordScroll();
    }

    public void RecordAppSwitch(string processName)
    {
        _lastAppSwitchTime = DateTime.UtcNow;
        _engineStartTime ??= _lastAppSwitchTime;
        _decisionEngine.RecordAppSwitch(processName);
    }

    public void SetMicActive(bool active) => _micActive = active;
    public void SetCameraActive(bool active) => _cameraActive = active;

    public void SetVideoPlaying(bool playing)
    {
        if (playing != _videoPlaying)
        {
            _videoPlaying = playing;
            if (playing)
            {
                _timer.ResetAfterBreak();
                _decisionEngine.ResetAll();
                OnTimerUpdate?.Invoke(_timer.RemainingSeconds, _timer.TimerDuration);
            }
        }
    }

    public void WakeFromSleep() => Tick();

    // MARK: - Break response

    public void UserTookBreak()
    {
        _consecutiveBreaks++;
        _complianceTracker.BreakTaken(DateTime.UtcNow, 20);
        FinishBreak();
    }

    public void UserSkippedBreak()
    {
        _complianceTracker.BreakDismissed(DateTime.UtcNow);
        FinishBreak();
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
        var now = DateTime.UtcNow;
        _engineStartTime ??= now;

        // 1. Pending break delivery
        if (_breakPending)
        {
            var waited = (now - (_breakPendingSince ?? now)).TotalSeconds;
            var kbIdle = _lastKeystrokeTime.HasValue ? (now - _lastKeystrokeTime.Value).TotalSeconds : 999;
            if (waited >= CourtesyWaitMax || kbIdle >= CourtesyGap)
            {
                _breakPending = false;
                _breakPendingSince = null;
                _isOnBreak = true;
                _complianceTracker.BreakPrompted(now, FlowState.Normal, 0);
                OnShowBreak?.Invoke(_consecutiveBreaks + 1);
                OnStateChange?.Invoke(DisplayState.OnBreak);
            }
            return;
        }

        if (_isOnBreak) return;

        // 2. Wall-clock safety cap
        var sinceLastBreak = (now - (_lastBreakEndedAt ?? _engineStartTime ?? now)).TotalSeconds;
        if (sinceLastBreak >= MaxWallClockSeconds)
        {
            _breakPending = true;
            _breakPendingSince = now;
            return;
        }

        // 3. Grace period
        var inGrace = _lastBreakEndedAt.HasValue &&
            (now - _lastBreakEndedAt.Value).TotalSeconds < GraceSeconds;

        // 4. Idle/meeting detection
        var idle = inGrace ? 0 : (now - LastActivityTime).TotalSeconds;
        var nowRef = ((DateTimeOffset)now).ToUnixTimeMilliseconds() / 1000.0;
        _stateMachine.Tick(0, idle, _micActive, _cameraActive, nowRef);

        var newState = MapState(_stateMachine.State);
        OnStateChange?.Invoke(newState);

        // 5. Idle reset
        if (idle >= IdleThreshold && !inGrace)
        {
            _consecutiveBreaks = 0;
            _decisionEngine.ResetAll();
            _timer.ResetAfterBreak();
            OnTimerUpdate?.Invoke(_timer.RemainingSeconds, _timer.TimerDuration);
            return;
        }

        if (_videoPlaying) return;

        // 6. Feed decision engine
        _decisionEngine.Tick(nowRef);

        // 7. Tick timer
        var timerState = _stateMachine.State is FlowState.Idle or FlowState.Meeting
            ? _stateMachine.State : FlowState.Normal;
        _timer.Tick(timerState, 1.0);
        OnTimerUpdate?.Invoke(_timer.RemainingSeconds, _timer.TimerDuration);
    }

    // MARK: - Break decision

    private void HandleBreakDue()
    {
        var decision = _decisionEngine.Decide(_config.MaxExtensions);

        switch (decision)
        {
            case BreakDecision.Extend ext:
                _decisionEngine.ResetWindow();
                _timer.Reset(10 * 60);
                OnShowExtendToast?.Invoke(ext.Reason);
                OnTimerUpdate?.Invoke(_timer.RemainingSeconds, _timer.TimerDuration);
                break;

            case BreakDecision.ShowBreak:
                _decisionEngine.ResetWindow();
                _breakPending = true;
                _breakPendingSince = DateTime.UtcNow;
                break;
        }
    }

    private void FinishBreak()
    {
        _lastBreakEndedAt = DateTime.UtcNow;
        _isOnBreak = false;
        _decisionEngine.ResetWindow();
        _timer.ResetAfterBreak();
        OnTimerUpdate?.Invoke(_timer.RemainingSeconds, _timer.TimerDuration);
        OnStateChange?.Invoke(DisplayState.Working);
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
}
