using System.ComponentModel;
using System.Runtime.CompilerServices;
using Blink.Core;
using Blink.Core.Abstractions;
using Blink.Core.Compliance;
using Blink.Core.FlowDetection;
using Blink.Platform;
using Blink.App.Theme;
using Microsoft.UI.Dispatching;
using Blink.App.Logging;

namespace Blink.App;

/// <summary>
/// Thin adapter between Windows platform layer and BlinkEngine.
/// Wires input hooks and Win32 APIs into the engine and responds to callbacks with UI.
/// </summary>
public sealed class AppState : INotifyPropertyChanged
{
    // Engine
    public BlinkEngine Engine { get; } = new();

    // Platform monitors
    private WinInputMonitor? _inputMonitor;
    private WinAppMonitor? _appMonitor;
    private WinIdleDetector? _idleDetector;
    private WinContextDetector? _contextDetector;

    // Timer
    private System.Threading.Timer? _tickTimer;

    // Overlay
    private Overlay.OverlayManager? _overlayManager;

    // Persistence
    private readonly Persistence.PersistenceManager _persistence = new();

    // Published state
    private double _remainingSeconds = 1200;
    private string _displayState = "Working";
    private bool _isBreakPrompted;
    private bool _isVideoPlaying;
    private int _breaksTakenToday;
    private int _breaksPromptedToday;

    public double RemainingSeconds { get => _remainingSeconds; private set => Set(ref _remainingSeconds, value); }
    public double TimerTotal { get; private set; } = 1200;
    public string DisplayStateName { get => _displayState; private set => Set(ref _displayState, value); }
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
        SetupEngineCallbacks();
        LoadTodayStats();
    }

    public void Start(DispatcherQueue dispatcher)
    {
        _overlayManager = new Overlay.OverlayManager(dispatcher);
        StartMonitoring();
        StartTimer();
    }

    private void SetupEngineCallbacks()
    {
        Engine.OnShowBreak = breakNumber =>
        {
            Log.Info($"Break prompted (streak={breakNumber})");
            IsBreakPrompted = true;
            BreaksPromptedToday++;
            _overlayManager?.ShowBreak(
                onComplete: () =>
                {
                    Log.Info("Break taken");
                    Engine.UserTookBreak();
                    IsBreakPrompted = false;
                    BreaksTakenToday++;
                },
                onSkip: () =>
                {
                    Log.Info("Break skipped");
                    Engine.UserSkippedBreak();
                    IsBreakPrompted = false;
                });
        };

        Engine.OnShowExtendToast = reason =>
        {
            Log.Info($"Timer extended: {reason}");
            _overlayManager?.ShowFlowNudge(
                $"{reason} — extended 10 min",
                () => Engine.UserTookBreak());
        };

        Engine.OnTimerUpdate = (remaining, total) =>
        {
            RemainingSeconds = remaining;
            TimerTotal = total;
        };

        Engine.OnStateChange = state =>
        {
            Log.Info($"State change → {state}");
            DisplayStateName = state.ToString();
        };

        Engine.Compliance.OnBreakRecorded += record =>
        {
            _persistence.SaveBreakRecord(record);
        };
    }

    private void StartMonitoring()
    {
        _inputMonitor = new WinInputMonitor();
        _inputMonitor.OnKeystroke += _ => Engine.RecordKeystroke();
        _inputMonitor.OnMouseEvent += evt =>
        {
            switch (evt.Kind)
            {
                case MouseEventKind.Click: Engine.RecordClick(); break;
                case MouseEventKind.Scroll: Engine.RecordScroll(); break;
            }
        };
        _inputMonitor.StartMonitoring();

        _appMonitor = new WinAppMonitor();
        _appMonitor.OnAppSwitch += evt => Engine.RecordAppSwitch(evt.AppId);
        _appMonitor.OnWindowTitleChange += () => { }; // no-op, engine doesn't track titles
        _appMonitor.StartMonitoring();

        _idleDetector = new WinIdleDetector();
        _contextDetector = new WinContextDetector();
    }

    private void StartTimer()
    {
        _tickTimer = new System.Threading.Timer(_ =>
        {
            // Poll context
            var mic = _contextDetector?.IsMicrophoneActive() ?? false;
            var cam = _contextDetector?.IsCameraActive() ?? false;
            var video = _contextDetector?.IsMediaPlaying() ?? false;
            // Treat a fullscreen app (game, presentation, exclusive-fullscreen D3D)
            // the same as video — pause the timer rather than interrupt.
            var fullscreen = _contextDetector?.IsFrontAppFullScreen() ?? false;
            var pauseTimer = video || fullscreen;
            Engine.SetMicActive(mic);
            Engine.SetCameraActive(cam);
            Engine.SetVideoPlaying(pauseTimer);
            IsVideoPlaying = pauseTimer;

            Engine.Tick();
        }, null, TimeSpan.FromSeconds(1), TimeSpan.FromSeconds(1));
    }

    public void ShowBreakPrompt()
    {
        IsBreakPrompted = true;
        BreaksPromptedToday++;
        _overlayManager?.ShowBreak(
            onComplete: () =>
            {
                Engine.UserTookBreak();
                IsBreakPrompted = false;
                BreaksTakenToday++;
            },
            onSkip: () =>
            {
                Engine.UserSkippedBreak();
                IsBreakPrompted = false;
            },
            breakNumber: Engine.CurrentBreakStreak + 1,
            skipToast: true);
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
