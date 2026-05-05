namespace Blink.App.Overlay;

/// <summary>
/// Manages the break overlay flow:
/// 1. Toast (3s heads-up, bottom-right, non-activating)
/// 2. Fullscreen countdown (3s)
/// 3. Break timer (20s, Esc=skip, →=extend)
/// </summary>
public sealed class OverlayManager
{
    private Action? _onComplete;
    private Action? _onSkip;

    public void ShowBreak(Action onComplete, Action onSkip)
    {
        _onComplete = onComplete;
        _onSkip = onSkip;

        // Phase 1: Toast notification
        ShowToast();
    }

    private void ShowToast()
    {
        // 3-second countdown toast in bottom-right
        // After 3 seconds, transition to fullscreen
        var timer = new System.Threading.Timer(_ =>
        {
            ShowFullscreenCountdown();
        }, null, TimeSpan.FromSeconds(3), System.Threading.Timeout.InfiniteTimeSpan);

        // TODO: Create WinUI toast window (borderless, topmost, non-activating)
    }

    private void ShowFullscreenCountdown()
    {
        // 3-second fullscreen countdown
        var timer = new System.Threading.Timer(_ =>
        {
            ShowBreakTimer();
        }, null, TimeSpan.FromSeconds(3), System.Threading.Timeout.InfiniteTimeSpan);

        // TODO: Create WinUI fullscreen window with countdown
    }

    private void ShowBreakTimer()
    {
        // 20-second break timer
        // Esc = skip, Right arrow = extend +20s
        // On completion, call _onComplete
        // On skip, call _onSkip

        // TODO: Create WinUI fullscreen window with break timer
        // For now, auto-complete after 20s
        var timer = new System.Threading.Timer(_ =>
        {
            _onComplete?.Invoke();
        }, null, TimeSpan.FromSeconds(20), System.Threading.Timeout.InfiniteTimeSpan);
    }

    public void Dismiss()
    {
        // TODO: Close all overlay windows
    }
}
