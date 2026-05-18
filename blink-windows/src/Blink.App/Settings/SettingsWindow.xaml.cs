using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Media;
using Blink.App.Theme;
using Blink.App.Onboarding;

namespace Blink.App.Settings;

public sealed partial class SettingsWindow : Window
{
    private readonly AppState _appState;
    private bool _isLoading = true;
    private string _currentFlowPreset = "balanced";

    public SettingsWindow(AppState appState)
    {
        _appState = appState;
        InitializeComponent();
        AppWindow.SetIcon(Path.Combine(AppContext.BaseDirectory, "app.ico"));

        const int width = 440;
        const int height = 480;
        var area = Microsoft.UI.Windowing.DisplayArea.Primary;
        var x = area.WorkArea.X + area.WorkArea.Width - width - 12;
        var y = area.WorkArea.Y + area.WorkArea.Height - height - 12;
        AppWindow.MoveAndResize(new Windows.Graphics.RectInt32(x, y, width, height));

        ApplyThemeBackground();
        LoadCurrentValues();
        _isLoading = false;
    }

    private void ApplyThemeBackground()
    {
        var theme = ThemeManager.Instance.Current;
        var isDark = Application.Current.RequestedTheme == ApplicationTheme.Dark;
        var top = theme.BackgroundTop(isDark);
        var bottom = theme.BackgroundBottom(isDark);
        RootNav.Background = new LinearGradientBrush
        {
            StartPoint = new Windows.Foundation.Point(0, 0),
            EndPoint = new Windows.Foundation.Point(0, 1),
            GradientStops =
            {
                new GradientStop { Color = top, Offset = 0 },
                new GradientStop { Color = bottom, Offset = 1 }
            }
        };
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

        _currentFlowPreset = ClosestPreset(tm.FlowSensitivity);
        FlowSensitivitySlider.Value = tm.FlowSensitivity * 100;
        FlowSensitivityLabel.Text = $"{(int)(tm.FlowSensitivity * 100)}%";
        UpdateFlowPresetUI();

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

    private void OnFlowPresetSelected(object sender, RoutedEventArgs e)
    {
        if (_isLoading) return;
        if (sender is Button btn && btn.Tag is string tag)
        {
            _currentFlowPreset = tag;
            var value = PresetToValue(tag);
            ThemeManager.Instance.FlowSensitivity = value;
            _appState.Engine.Sensitivity = value;
            _isLoading = true;
            FlowSensitivitySlider.Value = value * 100;
            FlowSensitivityLabel.Text = $"{(int)(value * 100)}%";
            _isLoading = false;
            UpdateFlowPresetUI();
        }
    }

    private void FlowSensitivitySlider_ValueChanged(object sender, Microsoft.UI.Xaml.Controls.Primitives.RangeBaseValueChangedEventArgs e)
    {
        if (_isLoading) return;
        var pct = (int)e.NewValue;
        var value = pct / 100.0;
        ThemeManager.Instance.FlowSensitivity = value;
        FlowSensitivityLabel.Text = $"{pct}%";
        _appState.Engine.Sensitivity = value;
        _currentFlowPreset = ClosestPreset(value);
        UpdateFlowPresetUI();
    }

    private void FineTuneToggle_Click(object sender, RoutedEventArgs e)
    {
        if (FineTunePanel.Visibility == Visibility.Collapsed)
        {
            FineTunePanel.Visibility = Visibility.Visible;
            FineTuneButton.Content = "Hide";
        }
        else
        {
            FineTunePanel.Visibility = Visibility.Collapsed;
            FineTuneButton.Content = "Fine-tune";
        }
    }

    private void UpdateFlowPresetUI()
    {
        var theme = ThemeManager.Instance.Current;
        var isDark = Application.Current.RequestedTheme == ApplicationTheme.Dark;
        var accent = theme.Accent(isDark);
        var fg = theme.OnBackgroundText(isDark);
        var accentBrush = new SolidColorBrush(accent);
        var fgBrush = new SolidColorBrush(fg);
        // Selected: accent at 12% bg + accent border (matches macOS)
        var selectedBg = new SolidColorBrush(
            Windows.UI.Color.FromArgb(40, accent.R, accent.G, accent.B));
        // Unselected: ~22% fg — Windows has no vibrancy, so higher than macOS's 4%
        var normalBg = new SolidColorBrush(
            Windows.UI.Color.FromArgb(56, fg.R, fg.G, fg.B));
        var transparentBorder = new SolidColorBrush(Microsoft.UI.Colors.Transparent);

        StylePresetButton(PresetEyeHealthBtn, _currentFlowPreset == "eyeHealth",
            selectedBg, normalBg, accentBrush, fgBrush, transparentBorder);
        StylePresetButton(PresetBalancedBtn, _currentFlowPreset == "balanced",
            selectedBg, normalBg, accentBrush, fgBrush, transparentBorder);
        StylePresetButton(PresetDeepWorkBtn, _currentFlowPreset == "deepWork",
            selectedBg, normalBg, accentBrush, fgBrush, transparentBorder);

        // "How this affects your breaks" button — accent tinted
        FlowLearnMoreButton.Background = new SolidColorBrush(
            Windows.UI.Color.FromArgb(25, accent.R, accent.G, accent.B));
        FlowLearnMoreIcon.Foreground = accentBrush;
        FlowLearnMoreText.Foreground = accentBrush;

        FlowSensitivityDescription.Text = GetPresetDescription(_currentFlowPreset);
    }

    private static void StylePresetButton(Button btn, bool isSelected,
        SolidColorBrush selectedBg, SolidColorBrush normalBg,
        SolidColorBrush accentBrush, SolidColorBrush fgBrush,
        SolidColorBrush transparentBorder)
    {
        btn.Background = isSelected ? selectedBg : normalBg;
        btn.BorderBrush = isSelected ? accentBrush : transparentBorder;
        btn.Foreground = isSelected ? accentBrush : fgBrush;
    }

    private void FlowLearnMore_Click(object sender, RoutedEventArgs e)
    {
        var sensitivity = ThemeManager.Instance.FlowSensitivity;
        var window = new FlowLearnMoreWindow(ThemeManager.Instance.Current, sensitivity);
        window.Activate();
    }

    private static double PresetToValue(string preset) => preset switch
    {
        "eyeHealth" => 0.45,
        "balanced" => 0.65,
        "deepWork" => 0.85,
        _ => 0.65
    };

    private static string ClosestPreset(double sensitivity)
    {
        if (sensitivity <= 0.55) return "eyeHealth";
        if (sensitivity <= 0.75) return "balanced";
        return "deepWork";
    }

    private static string GetPresetDescription(string preset) => preset switch
    {
        "eyeHealth" => "Blink prioritizes your eye health. Breaks come at 20 min unless your work rhythm is very intense.",
        "balanced" => "Blink learns your work rhythm and extends when you're truly focused. Recommended for most users.",
        "deepWork" => "Fewer interruptions during focus. Blink reminds you gently. Best if you're disciplined about breaks.",
        _ => ""
    };

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

    private void OnOpenLogs(object sender, RoutedEventArgs e)
    {
        var dir = Blink.App.Logging.Log.LogsDirectory;
        try { System.IO.Directory.CreateDirectory(dir); } catch { }
        Blink.App.Logging.Log.Info("User opened logs folder");
        System.Diagnostics.Process.Start(new System.Diagnostics.ProcessStartInfo
        {
            FileName = "explorer.exe",
            Arguments = $"\"{dir}\"",
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
