using System.Diagnostics;
using Blink.Core.Abstractions;
using Blink.Platform.Native;
using static Blink.Platform.Native.NativeMethods;

namespace Blink.Platform;

/// <summary>
/// Monitors keyboard and mouse input via low-level Windows hooks.
/// Only captures timestamps — never keycodes or content (privacy-safe).
/// Must be created on the UI thread (requires message pump).
/// </summary>
public sealed class WinInputMonitor : IInputEventSource, IDisposable
{
    public event Action<KeystrokeEvent>? OnKeystroke;
    public event Action<MouseEvent>? OnMouseEvent;

    private IntPtr _keyboardHook;
    private IntPtr _mouseHook;

    // Must hold references to prevent GC
    private LowLevelProc? _keyboardProc;
    private LowLevelProc? _mouseProc;

    private POINT _lastMousePos;

    public void StartMonitoring()
    {
        _keyboardProc = KeyboardHookCallback;
        _mouseProc = MouseHookCallback;

        using var process = Process.GetCurrentProcess();
        using var module = process.MainModule!;
        var hModule = GetModuleHandle(module.ModuleName);

        _keyboardHook = SetWindowsHookEx(WH_KEYBOARD_LL, _keyboardProc, hModule, 0);
        _mouseHook = SetWindowsHookEx(WH_MOUSE_LL, _mouseProc, hModule, 0);
    }

    public void StopMonitoring()
    {
        if (_keyboardHook != IntPtr.Zero)
        {
            UnhookWindowsHookEx(_keyboardHook);
            _keyboardHook = IntPtr.Zero;
        }
        if (_mouseHook != IntPtr.Zero)
        {
            UnhookWindowsHookEx(_mouseHook);
            _mouseHook = IntPtr.Zero;
        }
    }

    private IntPtr KeyboardHookCallback(int nCode, IntPtr wParam, IntPtr lParam)
    {
        if (nCode >= 0)
        {
            var msg = (int)wParam;
            if (msg is WM_KEYDOWN or WM_SYSKEYDOWN)
            {
                // Only capture timestamp — never the keycode
                var timestamp = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds() / 1000.0;
                OnKeystroke?.Invoke(new KeystrokeEvent(timestamp));
            }
        }
        return CallNextHookEx(_keyboardHook, nCode, wParam, lParam);
    }

    private IntPtr MouseHookCallback(int nCode, IntPtr wParam, IntPtr lParam)
    {
        if (nCode >= 0)
        {
            var timestamp = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds() / 1000.0;
            var msg = (int)wParam;
            var hookStruct = System.Runtime.InteropServices.Marshal.PtrToStructure<MSLLHOOKSTRUCT>(lParam);

            switch (msg)
            {
                case WM_MOUSEMOVE:
                    var dx = hookStruct.pt.x - _lastMousePos.x;
                    var dy = hookStruct.pt.y - _lastMousePos.y;
                    _lastMousePos = hookStruct.pt;
                    if (dx != 0 || dy != 0)
                        OnMouseEvent?.Invoke(new MouseEvent(timestamp, new MouseEventKind.Move(dx, dy)));
                    break;

                case WM_LBUTTONDOWN or WM_RBUTTONDOWN:
                    OnMouseEvent?.Invoke(new MouseEvent(timestamp, new MouseEventKind.Click()));
                    break;

                case WM_MOUSEWHEEL:
                    var delta = (short)(hookStruct.mouseData >> 16);
                    OnMouseEvent?.Invoke(new MouseEvent(timestamp, new MouseEventKind.Scroll(delta)));
                    break;
            }
        }
        return CallNextHookEx(_mouseHook, nCode, wParam, lParam);
    }

    public void Dispose() => StopMonitoring();
}
