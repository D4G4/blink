using System.ComponentModel;
using System.Runtime.CompilerServices;
using Blink.Core.Abstractions;
using Blink.Core.Compliance;
using Blink.Core.FlowDetection;
using Blink.Core.Timer;
using Blink.Platform;
using Blink.App.Theme;
using Microsoft.UI.Dispatching;

namespace Blink.App;

/// <summary>
/// Central app state — orchestrates all subsystems.
/// Port of macOS AppState.swift.
/// </summary>
public sealed class AppState : INotifyPropertyChanged
{
    // Constants
    private const double IdleBreakThreshold = 180;
    private const double NaturalPauseThreshold = 6;
    private const double MaxPauseWaitSeconds = 300;
    private const double ScoreTickIntervalMs = 30_000;
    private const double PostBreakGraceSeconds = 60;

    // Core engine
    public FlowScoreCalculator FlowScoreCalculator { get; } = new();
    public FlowStateMachine FlowStateMachine { get; } = new();
    public TimerStateMachine TimerStateMachine { get; } = new();
    public BreakComplianceTracker ComplianceTracker { get; } = new();
    public AdaptiveTimingEngine AdaptiveEngine { get; } = new();

    // Platform monitors
    private WinInputMonitor? _inputMonitor;
    private WinAppMonitor? _appMonitor;
    private WinIdleDetector? _idleDetector;
    private WinContextDetector? _contextDetector;

    // Timers
    private System.Threading.Timer? _tickTimer;
    private System.Threading.Timer? _scoreTimer;

    // Natural pause detection
    private bool _breakDuePending;
    private DateTime? _breakDueSince;
    private DateTime? _lastBreakEndedAt;

    // Overlay
    private Overlay.OverlayManager? _overlayManager;

    // Video state tracking for debug notifications
    private bool _wasVideoPlaying;

    // Persistence
    private readonly Persistence.PersistenceManager _persistence = new();

    // Published state
    private double _remainingSeconds = 1200;
    private FlowState _flowState = FlowState.Normal;
    private double _flowScore;
    private bool _isBreakPrompted;
    private bool _isVideoPlaying;
    private int _breaksTakenToday;
    private int _breaksPromptedToday;

    public double RemainingSeconds { get => _remainingSeconds; private set => Set(ref _remainingSeconds, value); }
    public FlowState CurrentFlowState { get => _flowState; private set => Set(ref _flowState, value); }
    public double FlowScore { get => _flowScore; private set => Set(ref _flowScore, value); }
    public bool IsBreakPrompted { get => _isBreakPrompted; private set => Set(ref _isBreakPrompted, value); }
    public bool IsVideoPlaying { get => _isVideoPlaying; private set => Set(ref _isVideoPlaying, value); }
    public int BreaksTakenToday { get => _breaksTakenToday; private set => Set(ref _breaksTakenToday, value); }
    public int BreaksPromptedToday { get => _breaksPromptedToday; private set => Set(ref _breaksPromptedToday, value); }

    public string FormattedRemaining
    {
        get
        {
            var mins = (int)RemainingSeconds / 60;
            var secs = (int)RemainingSeconds % 60;
            return $"{mins}:{secs:D2}";
        }
    }

    public AppState()
    {
        SetupCallbacks();
        LoadTodayStats();
    }

    public void Start(DispatcherQueue dispatcher)
    {
        _overlayManager = new Overlay.OverlayManager(dispatcher);
        StartMonitoring();
        StartTimers();
    }

    private void SetupCallbacks()
    {
        FlowStateMachine.OnStateChange += (old, @new) =>
        {
            CurrentFlowState = @new;
            if (@new == FlowState.BreakPrompted)
                IsBreakPrompted = true;

            if (ThemeManager.Instance.DebugNotifications)
                _overlayManager?.ShowDebugToast($"State: {old} → {@new}");
        };

        TimerStateMachine.OnBreakDue += HandleBreakDue;

        ComplianceTracker.OnBreakRecorded += record =>
        {
            _persistence.SaveBreakRecord(record);
            if (record.Compliance is BreakCompliance.Taken or BreakCompliance.Delayed)
            {
                BreaksTakenToday++;
                if (record.BreakDurationSeconds.HasValue)
                    AdaptiveEngine.RecordAcceptedBreak(record.BreakDurationSeconds.Value);
            }
        };
    }

    private void StartMonitoring()
    {
        _inputMonitor = new WinInputMonitor();
        _inputMonitor.OnKeystroke += evt => FlowScoreCalculator.IngestKeystroke(evt);
        _inputMonitor.OnMouseEvent += evt => FlowScoreCalculator.IngestMouseEvent(evt);
        _inputMonitor.StartMonitoring();

        _appMonitor = new WinAppMonitor();
        _appMonitor.OnAppSwitch += evt => FlowScoreCalculator.RecordAppSwitch(evt);
        _appMonitor.OnWindowTitleChange += () =>
            FlowScoreCalculator.RecordWindowTitleChange(
                DateTimeOffset.UtcNow.ToUnixTimeMilliseconds() / 1000.0);
        _appMonitor.StartMonitoring();

        _idleDetector = new WinIdleDetector();
        _contextDetector = new WinContextDetector();
    }

    private void StartTimers()
    {
        _tickTimer = new System.Threading.Timer(_ => TickCountdown(), null,
            TimeSpan.FromSeconds(1), TimeSpan.FromSeconds(1));

        _scoreTimer = new System.Threading.Timer(_ => TickFlowScore(), null,
            TimeSpan.FromMilliseconds(ScoreTickIntervalMs),
            TimeSpan.FromMilliseconds(ScoreTickIntervalMs));
    }

    private void TickCountdown()
    {
        CheckPendingBreak();
        if (IsBreakPrompted || _breakDuePending) return;

        var before = TimerStateMachine.RemainingSeconds;
        TimerStateMachine.Tick(CurrentFlowState, 1.0);
        RemainingSeconds = TimerStateMachine.RemainingSeconds;

        if (RemainingSeconds > before + 1)
        {
            _overlayManager?.ShowTimerExtendedToast(() => ShowBreakPrompt());

            if (ThemeManager.Instance.DebugNotifications)
                _overlayManager?.ShowDebugToast($"Timer extended: {(int)before}s → {(int)RemainingSeconds}s");
        }
    }

    private void TickFlowScore()
    {
        var now = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds() / 1000.0;
        var idle = _idleDetector?.SecondsSinceLastInput() ?? 0;
        var micActive = _contextDetector?.IsMicrophoneActive() ?? false;
        var camActive = _contextDetector?.IsCameraActive() ?? false;

        // Video detection
        var videoPlaying = _contextDetector?.IsMediaPlaying() ?? false;
        if (videoPlaying != _wasVideoPlaying && ThemeManager.Instance.DebugNotifications)
            _overlayManager?.ShowDebugToast(videoPlaying ? "Video started" : "Video stopped");
        _wasVideoPlaying = videoPlaying;
        IsVideoPlaying = videoPlaying;

        if (videoPlaying)
        {
            if (ThemeManager.Instance.DebugNotifications)
                _overlayManager?.ShowDebugToast("Timer reset: video playing");
            TimerStateMachine.ResetAfterBreak();
            RemainingSeconds = TimerStateMachine.RemainingSeconds;
            return;
        }

        FlowScore = FlowScoreCalculator.CurrentScore(now);

        var inGracePeriod = _lastBreakEndedAt.HasValue &&
            (DateTime.UtcNow - _lastBreakEndedAt.Value).TotalSeconds < PostBreakGraceSeconds;

        FlowStateMachine.Tick(
            FlowScore,
            inGracePeriod ? 0 : idle,
            micActive, camActive, now);

        // Idle = break (eyes rested)
        if (idle >= IdleBreakThreshold && !IsBreakPrompted && !inGracePeriod)
        {
            if (ThemeManager.Instance.DebugNotifications)
                _overlayManager?.ShowDebugToast($"Timer reset: idle {(int)idle}s >= {(int)IdleBreakThreshold}s");
            TimerStateMachine.ResetAfterBreak();
            RemainingSeconds = TimerStateMachine.RemainingSeconds;
        }
    }

    private void HandleBreakDue()
    {
        if (CurrentFlowState is FlowState.Flow or FlowState.DeepFlow)
        {
            _breakDuePending = true;
            _breakDueSince = DateTime.UtcNow;
            return;
        }
        ShowBreakPrompt();
    }

    private void CheckPendingBreak()
    {
        if (!_breakDuePending) return;

        var idle = _idleDetector?.SecondsSinceLastInput() ?? 0;
        var waited = (DateTime.UtcNow - (_breakDueSince ?? DateTime.UtcNow)).TotalSeconds;

        if (idle >= NaturalPauseThreshold)
        {
            _breakDuePending = false;
            _breakDueSince = null;
            ShowBreakPrompt();
            return;
        }

        if (waited >= MaxPauseWaitSeconds)
        {
            _breakDuePending = false;
            _breakDueSince = null;
            TimerStateMachine.ResetAfterBreak();
            RemainingSeconds = TimerStateMachine.RemainingSeconds;
        }
    }

    public void ShowBreakPrompt()
    {
        FlowStateMachine.EnterBreakPrompted();
        IsBreakPrompted = true;
        BreaksPromptedToday++;

        ComplianceTracker.BreakPrompted(DateTime.UtcNow, CurrentFlowState, FlowScore);

        _overlayManager?.ShowBreak(
            onComplete: () => TakeBreak(),
            onSkip: () => DismissBreak());
    }

    public void TakeBreak()
    {
        ComplianceTracker.BreakTaken(DateTime.UtcNow, 20);
        FinishBreak();
    }

    public void DismissBreak()
    {
        ComplianceTracker.BreakDismissed(DateTime.UtcNow);
        FinishBreak();
    }

    public void SnoozeBreak(int minutes)
    {
        IsBreakPrompted = false;
        FlowStateMachine.ExitBreakPrompted();
        TimerStateMachine.Reset(minutes * 60);
        RemainingSeconds = TimerStateMachine.RemainingSeconds;
    }

    private void FinishBreak()
    {
        _lastBreakEndedAt = DateTime.UtcNow;
        IsBreakPrompted = false;
        FlowStateMachine.ExitBreakPrompted();
        TimerStateMachine.ResetAfterBreak();
        RemainingSeconds = TimerStateMachine.RemainingSeconds;
    }

    private void LoadTodayStats()
    {
        var records = _persistence.LoadTodayRecords();
        BreaksPromptedToday = records.Count;
        BreaksTakenToday = records.Count(r => r.Compliance is BreakCompliance.Taken or BreakCompliance.Delayed);
    }

    // INotifyPropertyChanged
    public event PropertyChangedEventHandler? PropertyChanged;
    private void Set<T>(ref T field, T value, [CallerMemberName] string? name = null)
    {
        if (EqualityComparer<T>.Default.Equals(field, value)) return;
        field = value;
        PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(name));
    }
}
