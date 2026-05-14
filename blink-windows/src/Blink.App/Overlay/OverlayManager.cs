using Microsoft.UI.Xaml;

namespace Blink.App.Overlay;

/// <summary>
/// Manages the break overlay flow (matches macOS):
/// 1. Toast (3s heads-up, bottom-right)
/// 2. Break timer (20s, Esc=skip, Right=extend +20s)
///
/// Also provides standalone toasts for timer-extended and debug messages.
/// </summary>
public sealed class OverlayManager
{
    private readonly Microsoft.UI.Dispatching.DispatcherQueue _dispatcher;
    private Window? _currentToast;
    private Window? _currentFullscreen;

    public OverlayManager(Microsoft.UI.Dispatching.DispatcherQueue dispatcher)
    {
        _dispatcher = dispatcher;
    }

    /// <summary>
    /// Starts the full break flow: toast -> break timer.
    /// Pass breakNumber to show a walk suggestion when >= 4.
    /// </summary>
    public void ShowBreak(Action onComplete, Action onSkip, int breakNumber = 0)
    {
        _dispatcher.TryEnqueue(() =>
        {
            DismissAll();
            _currentToast = new ToastWindow(() =>
            {
                _currentToast?.Close();
                _currentToast = null;
                ShowBreakTimer(onComplete, onSkip, breakNumber);
            });
            _currentToast.Activate();
        });
    }

    private void ShowBreakTimer(Action onComplete, Action onSkip, int breakNumber)
    {
        _currentFullscreen = new BreakTimerWindow(
            onComplete: () =>
            {
                _currentFullscreen?.Close();
                _currentFullscreen = null;
                onComplete();
            },
            onSkip: () =>
            {
                _currentFullscreen?.Close();
                _currentFullscreen = null;
                onSkip();
            },
            breakNumber: breakNumber);
        _currentFullscreen.Activate();
    }

    /// <summary>
    /// Shows a toast indicating the timer was extended due to flow state,
    /// with a "Take break now" button.
    /// </summary>
    public void ShowTimerExtendedToast(Action onTakeBreakNow)
    {
        _dispatcher.TryEnqueue(() =>
        {
            var toast = new TimerExtendedToastWindow(() =>
            {
                onTakeBreakNow();
            });
            toast.Activate();
        });
    }

    /// <summary>
    /// Shows a gentle nudge toast during flow state instead of forcing the break overlay.
    /// Auto-dismisses after 7 seconds; "Break" button triggers onTakeBreak.
    /// </summary>
    public void ShowFlowNudge(string message, Action onTakeBreak)
    {
        _dispatcher.TryEnqueue(() =>
        {
            var toast = new FlowNudgeToastWindow(message, () => { onTakeBreak(); });
            toast.Activate();
        });
    }

    /// <summary>
    /// Shows a small debug toast in the top-right corner with an orange background.
    /// Auto-dismisses after 4 seconds. Non-interactive.
    /// </summary>
    public void ShowDebugToast(string message)
    {
        _dispatcher.TryEnqueue(() =>
        {
            var toast = new DebugToastWindow(message);
            toast.Activate();
        });
    }

    /// <summary>
    /// Dismisses all currently open overlay windows (toasts and fullscreen).
    /// </summary>
    public void Dismiss()
    {
        _dispatcher.TryEnqueue(DismissAll);
    }

    private void DismissAll()
    {
        _currentToast?.Close();
        _currentToast = null;
        _currentFullscreen?.Close();
        _currentFullscreen = null;
    }
}
