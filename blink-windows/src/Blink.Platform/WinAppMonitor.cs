using System.Diagnostics;
using System.Text;
using Blink.Core.Abstractions;
using Blink.Platform.Native;
using static Blink.Platform.Native.NativeMethods;

namespace Blink.Platform;

/// <summary>
/// Monitors foreground app switches and window title changes.
/// Uses SetWinEventHook for app switches, polls title every 5 seconds.
/// </summary>
public sealed class WinAppMonitor : IAppActivitySource, IDisposable
{
    public event Action<AppSwitchEvent>? OnAppSwitch;
    public event Action? OnWindowTitleChange;

    private IntPtr _eventHook;
    private WinEventDelegate? _winEventProc;
    private System.Threading.Timer? _titlePollTimer;
    private string? _lastWindowTitle;

    public void StartMonitoring()
    {
        _winEventProc = WinEventCallback;
        _eventHook = SetWinEventHook(
            EVENT_SYSTEM_FOREGROUND, EVENT_SYSTEM_FOREGROUND,
            IntPtr.Zero, _winEventProc,
            0, 0, WINEVENT_OUTOFCONTEXT);

        _titlePollTimer = new System.Threading.Timer(_ => CheckWindowTitle(), null,
            TimeSpan.FromSeconds(5), TimeSpan.FromSeconds(5));
    }

    public void StopMonitoring()
    {
        if (_eventHook != IntPtr.Zero)
        {
            UnhookWinEvent(_eventHook);
            _eventHook = IntPtr.Zero;
        }
        _titlePollTimer?.Dispose();
        _titlePollTimer = null;
    }

    private void WinEventCallback(
        IntPtr hWinEventHook, uint eventType, IntPtr hwnd,
        int idObject, int idChild, uint dwEventThread, uint dwmsEventTime)
    {
        if (eventType != EVENT_SYSTEM_FOREGROUND) return;

        try
        {
            GetWindowThreadProcessId(hwnd, out var pid);
            using var process = Process.GetProcessById((int)pid);
            var processName = process.ProcessName;

            var timestamp = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds() / 1000.0;
            OnAppSwitch?.Invoke(new AppSwitchEvent(timestamp, processName));
        }
        catch
        {
            // Process may have exited
        }
    }

    private void CheckWindowTitle()
    {
        try
        {
            var hwnd = GetForegroundWindow();
            if (hwnd == IntPtr.Zero) return;

            var sb = new StringBuilder(256);
            GetWindowText(hwnd, sb, sb.Capacity);
            var title = sb.ToString();

            if (title != _lastWindowTitle)
            {
                _lastWindowTitle = title;
                OnWindowTitleChange?.Invoke();
            }
        }
        catch
        {
            // Ignore errors during polling
        }
    }

    /// <summary>
    /// Gets the current foreground window title. Used by WinContextDetector.
    /// </summary>
    public static string? GetCurrentWindowTitle()
    {
        var hwnd = GetForegroundWindow();
        if (hwnd == IntPtr.Zero) return null;

        var sb = new StringBuilder(256);
        GetWindowText(hwnd, sb, sb.Capacity);
        var title = sb.ToString();
        return string.IsNullOrEmpty(title) ? null : title;
    }

    /// <summary>
    /// Gets the current foreground process name.
    /// </summary>
    public static string? GetCurrentProcessName()
    {
        try
        {
            var hwnd = GetForegroundWindow();
            if (hwnd == IntPtr.Zero) return null;

            GetWindowThreadProcessId(hwnd, out var pid);
            using var process = Process.GetProcessById((int)pid);
            return process.ProcessName;
        }
        catch
        {
            return null;
        }
    }

    public void Dispose() => StopMonitoring();
}
