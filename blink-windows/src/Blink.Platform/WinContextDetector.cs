using System.Diagnostics;
using Blink.Core.Abstractions;
using Blink.Platform.Native;
using static Blink.Platform.Native.NativeMethods;

namespace Blink.Platform;

/// <summary>
/// Detects meeting state, Focus Assist, fullscreen apps, and media playback on Windows.
/// </summary>
public sealed class WinContextDetector : IContextSource
{
    private static readonly HashSet<string> MeetingApps = new(StringComparer.OrdinalIgnoreCase)
    {
        "Zoom", "Teams", "ms-teams", "Webex",
        "Skype", "slack", "FaceTime"
    };

    private static readonly HashSet<string> VideoApps = new(StringComparer.OrdinalIgnoreCase)
    {
        "vlc", "mpv", "mpc-hc", "PotPlayerMini64",
        "wmplayer", "Movies & TV", "Video.UI",
        "plex", "Plex", "kodi"
    };

    private static readonly HashSet<string> Browsers = new(StringComparer.OrdinalIgnoreCase)
    {
        "chrome", "msedge", "firefox", "brave", "opera", "vivaldi", "Arc"
    };

    private static readonly string[] VideoTitleKeywords =
    [
        "youtube", "netflix", "hulu", "disney+", "prime video",
        "twitch", "vimeo", "dailymotion", "hbo", "peacock",
        "crunchyroll", "plex", "apple tv", "tubi"
    ];

    public bool IsMicrophoneActive()
    {
        // Check if a known meeting app is in the foreground
        var processName = WinAppMonitor.GetCurrentProcessName();
        return processName != null && MeetingApps.Contains(processName);
    }

    public bool IsCameraActive()
    {
        // Same heuristic as mic — meeting app is frontmost
        var processName = WinAppMonitor.GetCurrentProcessName();
        return processName != null && MeetingApps.Contains(processName);
    }

    public bool IsInFocusMode()
    {
        // Check Windows Focus Assist via registry
        // HKCU\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings
        // QuietHoursProfile values: 0=off, 1=priority, 2=alarms only
        try
        {
            using var key = Microsoft.Win32.Registry.CurrentUser.OpenSubKey(
                @"Software\Microsoft\Windows\CurrentVersion\Notifications\Settings");
            if (key?.GetValue("NOC_GLOBAL_SETTING_TOASTS_ENABLED") is int toasts)
                return toasts == 0; // 0 = notifications disabled
        }
        catch { }
        return false;
    }

    public bool IsFrontAppFullScreen()
    {
        // Primary signal: SHQueryUserNotificationState catches Direct3D-exclusive
        // games + presentation mode, which window-rect heuristics miss.
        if (SHQueryUserNotificationState(out var state) == 0)
        {
            if (state is QueryUserNotificationState.Busy
                       or QueryUserNotificationState.RunningD3dFullScreen
                       or QueryUserNotificationState.PresentationMode
                       or QueryUserNotificationState.App)
                return true;
        }

        // Fallback: foreground window covers the whole screen.
        var hwnd = GetForegroundWindow();
        if (hwnd == IntPtr.Zero) return false;
        if (!GetWindowRect(hwnd, out var rect)) return false;

        var screenW = GetSystemMetrics(SM_CXSCREEN);
        var screenH = GetSystemMetrics(SM_CYSCREEN);
        if (!(rect.Left <= 0 && rect.Top <= 0 && rect.Right >= screenW && rect.Bottom >= screenH))
            return false;

        // Don't count our own break-overlay or Gabor window as "fullscreen app".
        var processName = WinAppMonitor.GetCurrentProcessName();
        if (processName != null &&
            (processName.Equals("Blink.App", StringComparison.OrdinalIgnoreCase) ||
             processName.Equals("Blink-x64", StringComparison.OrdinalIgnoreCase) ||
             processName.Equals("Blink-arm64", StringComparison.OrdinalIgnoreCase)))
            return false;

        return true;
    }

    public bool IsMediaPlaying()
    {
        var processName = WinAppMonitor.GetCurrentProcessName();
        if (processName == null) return false;

        // Video app is frontmost
        if (VideoApps.Contains(processName)) return true;

        // Browser is frontmost — check window title for video sites
        if (Browsers.Contains(processName))
        {
            var title = WinAppMonitor.GetCurrentWindowTitle();
            if (title != null)
            {
                var titleLower = title.ToLowerInvariant();
                return VideoTitleKeywords.Any(kw => titleLower.Contains(kw));
            }
        }

        return false;
    }
}
