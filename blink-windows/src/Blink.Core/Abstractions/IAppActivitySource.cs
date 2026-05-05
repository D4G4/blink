namespace Blink.Core.Abstractions;

public interface IAppActivitySource
{
    event Action<AppSwitchEvent>? OnAppSwitch;
    event Action? OnWindowTitleChange;
    void StartMonitoring();
    void StopMonitoring();
}
