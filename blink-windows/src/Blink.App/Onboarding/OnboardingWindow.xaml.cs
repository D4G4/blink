using Microsoft.UI;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Media;
using Microsoft.UI.Xaml.Media.Imaging;
using Blink.App.Theme;
using Windows.UI;

namespace Blink.App.Onboarding;

public sealed partial class OnboardingWindow : Window
{
    private readonly ThemeManager _themeManager;
    private int _selectedIndex;
    private readonly BlinkTheme[] _themes = BlinkTheme.All;
    private double _sensitivity;
    private bool _isLoadingSlider = true;

    public OnboardingWindow(ThemeManager themeManager)
    {
        _themeManager = themeManager;
        _sensitivity = themeManager.FlowSensitivity;
        InitializeComponent();
        AppWindow.SetIcon(Path.Combine(AppContext.BaseDirectory, "app.ico"));

        // Start with Peach (or Midnight if system is dark)
        var isDark = Application.Current.RequestedTheme == ApplicationTheme.Dark;
        _selectedIndex = isDark
            ? Array.FindIndex(_themes, t => t.Id == "midnight")
            : Array.FindIndex(_themes, t => t.Id == "peach");
        if (_selectedIndex < 0) _selectedIndex = 0;

        UpdateThemeDisplay();

        // Initialize flow slider
        _isLoadingSlider = true;
        FlowSlider.Value = _sensitivity * 100;
        UpdateFlowDescription();
        _isLoadingSlider = false;

        // Set window size to 80% of screen
        var area = Microsoft.UI.Windowing.DisplayArea.Primary;
        var width = (int)(area.WorkArea.Width * 0.8);
        var height = (int)(area.WorkArea.Height * 0.8);
        AppWindow.Resize(new Windows.Graphics.SizeInt32(width, height));
        AppWindow.Move(new Windows.Graphics.PointInt32(
            (area.WorkArea.Width - width) / 2,
            (area.WorkArea.Height - height) / 2));
    }

    // ── Theme Page ──

    private void UpdateThemeDisplay()
    {
        var theme = _themes[_selectedIndex];
        bool isDark = Application.Current.RequestedTheme == ApplicationTheme.Dark;

        ThemeName.Text = theme.Name;

        var iconPath = Path.Combine(AppContext.BaseDirectory, "Assets", $"theme-{theme.Id}.png");
        if (File.Exists(iconPath))
            ThemeIcon.Source = new BitmapImage(new Uri(iconPath));

        // Background gradient from theme colors
        var topColor = theme.BackgroundTop(isDark);
        var bottomColor = theme.BackgroundBottom(isDark);
        RootGrid.Background = new LinearGradientBrush
        {
            StartPoint = new Windows.Foundation.Point(0, 0),
            EndPoint = new Windows.Foundation.Point(0, 1),
            GradientStops =
            {
                new GradientStop { Color = topColor, Offset = 0 },
                new GradientStop { Color = bottomColor, Offset = 1 }
            }
        };

        // Update text color to match theme's on-background color
        var textColor = theme.OnBackgroundText(isDark);
        var textBrush = new SolidColorBrush(textColor);
        ThemeName.Foreground = textBrush;
    }

    private void OnPrevious(object sender, RoutedEventArgs e)
    {
        _selectedIndex = (_selectedIndex - 1 + _themes.Length) % _themes.Length;
        UpdateThemeDisplay();
    }

    private void OnNext(object sender, RoutedEventArgs e)
    {
        _selectedIndex = (_selectedIndex + 1) % _themes.Length;
        UpdateThemeDisplay();
    }

    private void OnContinueToFlow(object sender, RoutedEventArgs e)
    {
        // Save theme selection and switch to flow page
        _themeManager.Select(_themes[_selectedIndex]);
        ShowFlowPage();
    }

    private void OnWhyExist(object sender, RoutedEventArgs e)
    {
        var window = new WhyExistWindow(_themes[_selectedIndex]);
        window.Activate();
    }

    // ── Flow Sensitivity Page ──

    private void ShowFlowPage()
    {
        ThemePage.Visibility = Visibility.Collapsed;
        FlowPage.Visibility = Visibility.Visible;
        ApplyFlowPageTheme();
    }

    private void ShowThemePage()
    {
        FlowPage.Visibility = Visibility.Collapsed;
        ThemePage.Visibility = Visibility.Visible;
    }

    private void ApplyFlowPageTheme()
    {
        var theme = _themes[_selectedIndex];
        var isDark = Application.Current.RequestedTheme == ApplicationTheme.Dark;
        var fg = theme.OnBackgroundText(isDark);
        var fgBrush = new SolidColorBrush(fg);
        var accent = theme.Accent(isDark);
        var accentBrush = new SolidColorBrush(accent);

        // Text colors
        FlowTitle.Foreground = fgBrush;
        FlowSubtitle.Foreground = fgBrush;
        FlowIcon.Foreground = new SolidColorBrush(fg) { Opacity = 0.7 };
        BackLabel.Foreground = new SolidColorBrush(fg) { Opacity = 0.7 };
        SliderTitle.Foreground = fgBrush;
        SliderLowLabel.Foreground = fgBrush;
        SliderHighLabel.Foreground = fgBrush;
        FlowPctLabel.Foreground = fgBrush;
        FlowDescLabel.Foreground = fgBrush;

        // Slider card background
        SliderCard.Background = new SolidColorBrush(
            Color.FromArgb(20, fg.R, fg.G, fg.B));

        // Explore button styling
        ExploreButton.Foreground = new SolidColorBrush(Colors.White);

        // Get Started button
        GetStartedButton.Background = fgBrush;
        GetStartedButton.Foreground = new SolidColorBrush(theme.BackgroundTop(isDark));
    }

    private void OnBackToThemes(object sender, RoutedEventArgs e)
    {
        ShowThemePage();
    }

    private void FlowSlider_ValueChanged(object sender, Microsoft.UI.Xaml.Controls.Primitives.RangeBaseValueChangedEventArgs e)
    {
        if (_isLoadingSlider) return;
        var pct = (int)e.NewValue;
        _sensitivity = pct / 100.0;
        _themeManager.FlowSensitivity = _sensitivity;
        UpdateFlowDescription();
    }

    private void UpdateFlowDescription()
    {
        var pct = (int)(_sensitivity * 100);
        FlowPctLabel.Text = $"{pct}%";
        FlowDescLabel.Text = GetFlowSensitivityDescription(_sensitivity);
    }

    private void OnExploreHowItWorks(object sender, RoutedEventArgs e)
    {
        var theme = _themes[_selectedIndex];
        var window = new FlowLearnMoreWindow(theme, _sensitivity);
        window.Activate();
    }

    private void OnGetStarted(object sender, RoutedEventArgs e)
    {
        _themeManager.Select(_themes[_selectedIndex]);
        _themeManager.FlowSensitivity = _sensitivity;
        _themeManager.HasCompletedOnboarding = true;
        Close();
    }

    // ── Shared helpers ──

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
}
