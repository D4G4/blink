using Blink.Core.Abstractions;
using Blink.Platform.Native;

namespace Blink.Platform;

/// <summary>
/// Detects system idle time using GetLastInputInfo.
/// Simplest adapter — single P/Invoke call.
/// </summary>
public sealed class WinIdleDetector : IIdleStateSource
{
    public double SecondsSinceLastInput()
    {
        var info = new NativeMethods.LASTINPUTINFO
        {
            cbSize = (uint)System.Runtime.InteropServices.Marshal.SizeOf<NativeMethods.LASTINPUTINFO>()
        };

        if (!NativeMethods.GetLastInputInfo(ref info))
            return 0;

        var idleMs = (uint)Environment.TickCount - info.dwTime;
        return idleMs / 1000.0;
    }
}
