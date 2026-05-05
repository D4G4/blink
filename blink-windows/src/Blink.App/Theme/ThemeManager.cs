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
