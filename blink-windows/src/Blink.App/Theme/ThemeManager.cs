using Windows.Storage;

namespace Blink.App.Theme;

public sealed class ThemeManager
{
    public static ThemeManager Instance { get; } = new();

    public BlinkTheme Current { get; private set; }
    public bool HasCompletedOnboarding
    {
        get => GetSetting("hasCompletedOnboarding", false);
        set => SetSetting("hasCompletedOnboarding", value);
    }

    private ThemeManager()
    {
        var id = GetSetting("selectedTheme", "peach");
        Current = BlinkTheme.Named(id);
    }

    public double BaseInterval
    {
        get => GetSetting("baseInterval", 20.0);
        set => SetSetting("baseInterval", value);
    }

    public double FlowSensitivity
    {
        get => GetSetting("flowSensitivity", 0.7);
        set => SetSetting("flowSensitivity", value);
    }

    public bool ShowTimerInTray
    {
        get => GetSetting("showTimerInTray", false);
        set => SetSetting("showTimerInTray", value);
    }

    public bool UseDarkOverlay
    {
        get => GetSetting("useDarkOverlay", false);
        set => SetSetting("useDarkOverlay", value);
    }

    public bool LaunchAtLogin
    {
        get => GetSetting("launchAtLogin", false);
        set => SetSetting("launchAtLogin", value);
    }

    public bool DebugNotifications
    {
        get => GetSetting("debugNotifications", false);
        set => SetSetting("debugNotifications", value);
    }

    public void Select(BlinkTheme theme)
    {
        Current = theme;
        SetSetting("selectedTheme", theme.Id);
    }

    private static T GetSetting<T>(string key, T defaultValue)
    {
        var settings = ApplicationData.Current.LocalSettings;
        return settings.Values.TryGetValue(key, out var value) && value is T typed
            ? typed : defaultValue;
    }

    private static void SetSetting<T>(string key, T value)
    {
        ApplicationData.Current.LocalSettings.Values[key] = value;
    }
}
