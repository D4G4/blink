using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Blink.App.Theme;
using Blink.App.Onboarding;

namespace Blink.App.Settings;

public sealed partial class SettingsWindow : Window
{
    private readonly AppState _appState;
    private bool _isLoading = true;

    public SettingsWindow(AppState appState)
    {
        _appState = appState;
        InitializeComponent();
        AppWindow.SetIcon(Path.Combine(AppContext.BaseDirectory, "app.ico"));
        AppWindow.Resize(new Windows.Graphics.SizeInt32(440, 480));
        LoadCurrentValues();
        _isLoading = false;
    }

    private void LoadCurrentValues()
    {
        var tm = ThemeManager.Instance;
        BaseIntervalSlider.Value = tm.BaseInterval;
        BaseIntervalLabel.Text = $"{(int)tm.BaseInterval} min";
        ShowTimerToggle.IsOn = tm.ShowTimerInTray;
        DarkOverlayToggle.IsOn = tm.UseDarkOverlay;
        LaunchAtLoginToggle.IsOn = tm.LaunchAtLogin;
        DebugToggle.IsOn = tm.DebugNotifications;

        FlowSensitivitySlider.Value = tm.FlowSensitivity * 100;
        FlowSensitivityLabel.Text = $"{(int)(tm.FlowSensitivity * 100)}%";
        FlowSensitivityDescription.Text = GetFlowSensitivityDescription(tm.FlowSensitivity);

        FlowScoreValue.Text = "—";
        FlowStateValue.Text = _appState.DisplayStateName;
        BreaksTodayValue.Text = $"{_appState.BreaksTakenToday} / {_appState.BreaksPromptedToday}";

        var version = typeof(SettingsWindow).Assembly.GetName().Version;
        VersionText.Text = $"Version {version?.ToString(3) ?? "1.0.0"}";

        PopulateThemeGrid();
    }

    private void PopulateThemeGrid()
    {
        var themes = BlinkTheme.All;
        var items = new List<FrameworkElement>();
        foreach (var theme in themes)
        {
            var isSelected = theme.Id == ThemeManager.Instance.Current.Id;
            var border = new Border
            {
                Width = 120,
                Height = 80,
                CornerRadius = new CornerRadius(8),
                BorderThickness = new Thickness(isSelected ? 3 : 1),
                BorderBrush = isSelected
                    ? new Microsoft.UI.Xaml.Media.SolidColorBrush(theme.Accent(false))
                    : new Microsoft.UI.Xaml.Media.SolidColorBrush(Microsoft.UI.Colors.Gray),
                Background = new Microsoft.UI.Xaml.Media.SolidColorBrush(theme.BackgroundTop(false)),
                Tag = theme,
                Padding = new Thickness(8),
                Child = new TextBlock
                {
                    Text = theme.Name,
                    VerticalAlignment = VerticalAlignment.Bottom,
                    HorizontalAlignment = HorizontalAlignment.Center,
                    Foreground = new Microsoft.UI.Xaml.Media.SolidColorBrush(theme.OnBackgroundText(false))
                }
            };
            border.PointerPressed += (s, e) =>
            {
                if (s is Border b && b.Tag is BlinkTheme t)
                {
                    ThemeManager.Instance.Select(t);
                    PopulateThemeGrid();
                }
            };
            items.Add(border);
        }
        ThemeGrid.ItemsSource = items;
    }

    private void NavigationView_SelectionChanged(NavigationView sender, NavigationViewSelectionChangedEventArgs args)
    {
        if (args.SelectedItem is NavigationViewItem item && item.Tag is string tag)
        {
            GeneralPanel.Visibility = tag == "general" ? Visibility.Visible : Visibility.Collapsed;
            ThemePanel.Visibility = tag == "theme" ? Visibility.Visible : Visibility.Collapsed;
            FlowPanel.Visibility = tag == "flow" ? Visibility.Visible : Visibility.Collapsed;
            AboutPanel.Visibility = tag == "about" ? Visibility.Visible : Visibility.Collapsed;
        }
    }

    private void BaseIntervalSlider_ValueChanged(object sender, Microsoft.UI.Xaml.Controls.Primitives.RangeBaseValueChangedEventArgs e)
    {
        if (_isLoading) return;
        var value = (int)e.NewValue;
        ThemeManager.Instance.BaseInterval = value;
        BaseIntervalLabel.Text = $"{value} min";
        // Timer duration is fixed at 20 min — setting stored for future use
    }

    private void ShowTimerToggle_Toggled(object sender, RoutedEventArgs e)
    {
        if (_isLoading) return;
        ThemeManager.Instance.ShowTimerInTray = ShowTimerToggle.IsOn;
    }

    private void DarkOverlayToggle_Toggled(object sender, RoutedEventArgs e)
    {
        if (_isLoading) return;
        ThemeManager.Instance.UseDarkOverlay = DarkOverlayToggle.IsOn;
    }

    private void LaunchAtLoginToggle_Toggled(object sender, RoutedEventArgs e)
    {
        if (_isLoading) return;
        ThemeManager.Instance.LaunchAtLogin = LaunchAtLoginToggle.IsOn;
        UpdateLaunchAtLogin(LaunchAtLoginToggle.IsOn);
    }

    private void DebugToggle_Toggled(object sender, RoutedEventArgs e)
    {
        if (_isLoading) return;
        ThemeManager.Instance.DebugNotifications = DebugToggle.IsOn;
    }

    private void FlowSensitivitySlider_ValueChanged(object sender, Microsoft.UI.Xaml.Controls.Primitives.RangeBaseValueChangedEventArgs e)
    {
        if (_isLoading) return;
        var pct = (int)e.NewValue;
        var value = pct / 100.0;
        ThemeManager.Instance.FlowSensitivity = value;
        FlowSensitivityLabel.Text = $"{pct}%";
        FlowSensitivityDescription.Text = GetFlowSensitivityDescription(value);
        _appState.Engine.Sensitivity = value;
    }

    private void FlowLearnMore_Click(object sender, RoutedEventArgs e)
    {
        var sensitivity = ThemeManager.Instance.FlowSensitivity;
        var window = new FlowLearnMoreWindow(ThemeManager.Instance.Current, sensitivity);
        window.Activate();
    }

    private static int GetGapTolerance(double sensitivity)
    {
        var t = (sensitivity - 0.4) / (0.9 - 0.4);
        return (int)Math.Round(15 + t * 75);
    }

    private static string GetFlowSensitivityDescription(double sensitivity)
    {
        var gap = GetGapTolerance(sensitivity);
        return sensitivity switch
        {
            < 0.5 => $"Strict \u2014 pauses over {gap}s break flow. Only continuous action counts.",
            < 0.6 => $"Conservative \u2014 pauses up to {gap}s keep flow. Short thinking breaks are OK.",
            < 0.7 => $"Balanced \u2014 pauses up to {gap}s keep flow. Brief reading won't interrupt.",
            < 0.8 => $"Recommended \u2014 pauses up to {gap}s keep flow. Natural thinking stays in flow.",
            < 0.9 => $"Relaxed \u2014 pauses up to {gap}s keep flow. Long reading sessions are fine.",
            _ => $"Very relaxed \u2014 pauses up to {gap}s keep flow. Almost any activity counts."
        };
    }

    private void UpdateButton_Click(object sender, RoutedEventArgs e)
    {
        UpdateButton.IsEnabled = false;
        UpdateProgress.Visibility = Visibility.Visible;
        UpdateProgress.IsActive = true;
        UpdateStatusText.Text = "Checking...";
        DownloadUpdateButton.Visibility = Visibility.Collapsed;

        var checker = UpdateChecker.Instance;
        checker.PropertyChanged += OnUpdateCheckerChanged;
        checker.CheckForUpdate();
    }

    private void OnUpdateCheckerChanged(object? sender, System.ComponentModel.PropertyChangedEventArgs e)
    {
        if (e.PropertyName != nameof(UpdateChecker.IsChecking)) return;
        var checker = UpdateChecker.Instance;
        if (checker.IsChecking) return;

        checker.PropertyChanged -= OnUpdateCheckerChanged;

        DispatcherQueue.TryEnqueue(() =>
        {
            UpdateButton.IsEnabled = true;
            UpdateProgress.Visibility = Visibility.Collapsed;
            UpdateProgress.IsActive = false;

            UpdateStatusText.Text = checker.LastCheckResult?.Kind switch
            {
                UpdateChecker.CheckResultKind.UpToDate => "Up to date",
                UpdateChecker.CheckResultKind.Available => $"v{checker.LatestVersion} available",
                UpdateChecker.CheckResultKind.Failed => "Check failed",
                _ => ""
            };

            DownloadUpdateButton.Visibility =
                checker.LastCheckResult?.Kind == UpdateChecker.CheckResultKind.Available
                && !string.IsNullOrEmpty(checker.DownloadUrl)
                    ? Visibility.Visible : Visibility.Collapsed;
        });
    }

    private void DownloadUpdate_Click(object sender, RoutedEventArgs e)
    {
        var url = UpdateChecker.Instance.DownloadUrl;
        if (string.IsNullOrEmpty(url)) return;
        System.Diagnostics.Process.Start(new System.Diagnostics.ProcessStartInfo
        {
            FileName = url,
            UseShellExecute = true
        });
    }

    private void RestartOnboarding_Click(object sender, RoutedEventArgs e)
    {
        ThemeManager.Instance.HasCompletedOnboarding = false;
        var path = Environment.ProcessPath;
        if (path != null) System.Diagnostics.Process.Start(path);
        Application.Current.Exit();
    }

    private static void UpdateLaunchAtLogin(bool enabled)
    {
        try
        {
            using var key = Microsoft.Win32.Registry.CurrentUser.OpenSubKey(
                @"Software\Microsoft\Windows\CurrentVersion\Run", true);
            if (enabled)
            {
                var exePath = Environment.ProcessPath ?? "";
                key?.SetValue("Blink", $"\"{exePath}\"");
            }
            else
            {
                key?.DeleteValue("Blink", false);
            }
        }
        catch { /* ignore on failure */ }
    }
}
