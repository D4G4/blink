using System.Drawing;
using System.Runtime.InteropServices;
using Blink.Platform.Native;
using static Blink.Platform.Native.NativeMethods;

namespace Blink.App.TrayIcon;

/// <summary>
/// System tray icon using Shell_NotifyIcon.
/// Shows timer countdown in tooltip, context menu on right-click.
/// </summary>
public sealed class TrayIconManager : IDisposable
{
    private readonly AppState _appState;
    private NOTIFYICONDATA _iconData;
    private IntPtr _hWnd;
    private bool _isShowing;

    public const uint WM_TRAYICON = 0x8000 + 1; // WM_APP + 1

    public TrayIconManager(AppState appState)
    {
        _appState = appState;
    }

    public void Show()
    {
        _iconData = new NOTIFYICONDATA
        {
            cbSize = (uint)Marshal.SizeOf<NOTIFYICONDATA>(),
            hWnd = _hWnd,
            uID = 1,
            uFlags = NIF_ICON | NIF_TIP | NIF_MESSAGE,
            uCallbackMessage = WM_TRAYICON,
            szTip = $"Blink — Next break in {_appState.FormattedRemaining}"
        };

        Shell_NotifyIcon(NIM_ADD, ref _iconData);
        _isShowing = true;

        // Update tooltip periodically
        var timer = new System.Threading.Timer(_ => UpdateTooltip(), null,
            TimeSpan.FromSeconds(10), TimeSpan.FromSeconds(10));
    }

    public void UpdateTooltip()
    {
        if (!_isShowing) return;

        _iconData.szTip = $"Blink — Next break in {_appState.FormattedRemaining}";
        _iconData.uFlags = NIF_TIP;
        Shell_NotifyIcon(NIM_MODIFY, ref _iconData);
    }

    public void Dispose()
    {
        if (_isShowing)
        {
            Shell_NotifyIcon(NIM_DELETE, ref _iconData);
            _isShowing = false;
        }
    }
}
