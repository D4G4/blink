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
    private System.Threading.Timer? _tooltipTimer;

    // prevent GC of the delegate
    private readonly WndProc _wndProcDelegate;

    private const uint WM_TRAYICON = 0x8000 + 1; // WM_APP + 1
    private const uint IDM_SETTINGS = 1;
    private const uint IDM_TAKE_BREAK = 2;
    private const uint IDM_QUIT = 3;

    public event Action? OnSettingsRequested;
    public event Action? OnTakeBreakNowRequested;
    public event Action? OnQuitRequested;

    public TrayIconManager(AppState appState)
    {
        _appState = appState;
        _wndProcDelegate = WndProcHandler;
        CreateMessageWindow();
    }

    private void CreateMessageWindow()
    {
        var hInstance = GetModuleHandle(null);
        var className = "BlinkTrayMsg";

        var wc = new WNDCLASS
        {
            lpfnWndProc = _wndProcDelegate,
            hInstance = hInstance,
            lpszClassName = className
        };
        RegisterClass(ref wc);

        _hWnd = CreateWindowEx(
            0, className, "Blink Tray", 0,
            0, 0, 0, 0,
            IntPtr.Zero, IntPtr.Zero, hInstance, IntPtr.Zero);
    }

    private IntPtr WndProcHandler(IntPtr hWnd, uint msg, IntPtr wParam, IntPtr lParam)
    {
        if (msg == WM_TRAYICON)
        {
            var mouseMsg = (uint)(lParam.ToInt64() & 0xFFFF);
            if (mouseMsg == WM_RBUTTONUP)
                ShowContextMenu();
            else if (mouseMsg == WM_LBUTTONUP)
                OnSettingsRequested?.Invoke();
        }
        return DefWindowProc(hWnd, msg, wParam, lParam);
    }

    private void ShowContextMenu()
    {
        var hMenu = CreatePopupMenu();
        AppendMenu(hMenu, MF_STRING, IDM_SETTINGS, "Settings");
        AppendMenu(hMenu, MF_STRING, IDM_TAKE_BREAK, "Take Break Now");
        AppendMenu(hMenu, MF_SEPARATOR, 0, "");
        AppendMenu(hMenu, MF_STRING, IDM_QUIT, "Quit Blink");

        GetCursorPos(out var pt);
        SetForegroundWindow(_hWnd);
        var cmd = TrackPopupMenu(hMenu, TPM_RETURNCMD | TPM_NONOTIFY,
            pt.x, pt.y, 0, _hWnd, IntPtr.Zero);
        DestroyMenu(hMenu);
        PostMessage(_hWnd, WM_NULL, IntPtr.Zero, IntPtr.Zero);

        switch ((uint)cmd)
        {
            case IDM_SETTINGS:
                OnSettingsRequested?.Invoke();
                break;
            case IDM_TAKE_BREAK:
                OnTakeBreakNowRequested?.Invoke();
                break;
            case IDM_QUIT:
                OnQuitRequested?.Invoke();
                break;
        }
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

        _tooltipTimer = new System.Threading.Timer(_ => UpdateTooltip(), null,
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
        _tooltipTimer?.Dispose();
        if (_isShowing)
        {
            Shell_NotifyIcon(NIM_DELETE, ref _iconData);
            _isShowing = false;
        }
        if (_hWnd != IntPtr.Zero)
        {
            DestroyWindow(_hWnd);
            _hWnd = IntPtr.Zero;
        }
    }
}
