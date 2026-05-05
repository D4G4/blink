namespace Blink.Core.Abstractions;

public interface IInputEventSource
{
    event Action<KeystrokeEvent>? OnKeystroke;
    event Action<MouseEvent>? OnMouseEvent;
    void StartMonitoring();
    void StopMonitoring();
}
