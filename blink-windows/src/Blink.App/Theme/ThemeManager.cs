using System.Text.Json;
using System.Text.Json.Nodes;

namespace Blink.App.Theme;

public sealed class ThemeManager
{
    private static readonly string SettingsPath = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
        "Blink",
        "settings.json");

    public static ThemeManager Instance { get; } = new();

    private readonly object _gate = new();
    private JsonObject _values;

    public BlinkTheme Current { get; private set; }

    public bool HasCompletedOnboarding
    {
        get => GetSetting("hasCompletedOnboarding", false);
        set => SetSetting("hasCompletedOnboarding", value);
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

    private ThemeManager()
    {
        _values = LoadFromDisk();
        var id = GetSetting("selectedTheme", "peach");
        Current = BlinkTheme.Named(id);
    }

    public void Select(BlinkTheme theme)
    {
        Current = theme;
        SetSetting("selectedTheme", theme.Id);
    }

    private static JsonObject LoadFromDisk()
    {
        try
        {
            if (File.Exists(SettingsPath))
            {
                var text = File.ReadAllText(SettingsPath);
                if (JsonNode.Parse(text) is JsonObject obj) return obj;
            }
        }
        catch { }
        return new JsonObject();
    }

    private void SaveToDisk()
    {
        Directory.CreateDirectory(Path.GetDirectoryName(SettingsPath)!);
        File.WriteAllText(SettingsPath, _values.ToJsonString(new JsonSerializerOptions { WriteIndented = true }));
    }

    private T GetSetting<T>(string key, T defaultValue)
    {
        lock (_gate)
        {
            if (!_values.TryGetPropertyValue(key, out var node) || node is null) return defaultValue;
            try { return node.GetValue<T>(); }
            catch { return defaultValue; }
        }
    }

    private void SetSetting<T>(string key, T value)
    {
        lock (_gate)
        {
            _values[key] = JsonValue.Create(value);
            SaveToDisk();
        }
    }
}
