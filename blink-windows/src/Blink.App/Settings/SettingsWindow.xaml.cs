using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Blink.App.Theme;

namespace Blink.App.Settings;

public sealed partial class SettingsWindow : Window
{
    private readonly AppState _appState;
    private bool _isLoading = true;

    public SettingsWindow(AppState appState)
    {
        _appState = appState;
        InitializeComponent();
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

        FlowScoreValue.Text = $"{_appState.FlowScore:P0}";
        FlowStateValue.Text = _appState.CurrentFlowState.ToString();
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
        _appState.TimerStateMachine.NormalDuration = value * 60;
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
        _appState.FlowStateMachine.FlowEntryThreshold = value;
    }

    private void UpdateButton_Click(object sender, RoutedEventArgs e)
    {
        UpdateButton.IsEnabled = false;
        UpdateProgress.Visibility = Visibility.Visible;
        UpdateProgress.IsActive = true;
        UpdateStatusText.Text = "Checking...";

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
