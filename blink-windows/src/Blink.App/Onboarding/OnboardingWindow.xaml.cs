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
    private string _selectedPreset = "balanced";

    // Onboarding always opens in the LIGHT variant — Peach-in-light is the
    // brand's first impression, regardless of the user's system appearance.
    // The "Preview dark" toggle flips this on demand. This deliberately does
    // NOT read Application.Current.RequestedTheme; every theme method below
    // is passed _previewDark so onboarding shows the theme's real light
    // colors, not the dark-tinted overlay variant. (macOS commit f0f3391.)
    private bool _previewDark;

    public OnboardingWindow(ThemeManager themeManager)
    {
        _themeManager = themeManager;
        // First-run onboarding always pre-highlights Balanced — the canonical
        // default a fresh user gets (matches macOS FlowSensitivityView.Preset
        // .balanced). If the user re-opens onboarding after having set a value,
        // start from their stored sensitivity instead. Note: we don't inherit
        // ThemeManager's raw stored default here so the pre-highlighted card
        // and the value persisted on Get Started always agree.
        _sensitivity = themeManager.HasCompletedOnboarding
            ? themeManager.FlowSensitivity
            : FlowSensitivityPreset.Default;
        InitializeComponent();
        AppWindow.SetIcon(Path.Combine(AppContext.BaseDirectory, "app.ico"));

        // Always start on Peach (theme list is Peach-first), light variant.
        _selectedIndex = Array.FindIndex(_themes, t => t.Id == "peach");
        if (_selectedIndex < 0) _selectedIndex = 0;

        UpdateThemeDisplay();

        // Initialize preset selection based on current sensitivity
        _selectedPreset = ClosestPreset(_sensitivity);
        UpdatePresetSelection();

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
        bool isDark = _previewDark;

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
        WelcomeTitle.Foreground = textBrush;
        WelcomeSubtitle.Foreground = textBrush;
        ThemeName.Foreground = textBrush;

        // Preview-dark toggle: fg text on a translucent fg capsule (matches macOS).
        PreviewDarkIcon.Foreground = textBrush;
        PreviewDarkLabel.Foreground = textBrush;
        PreviewDarkButton.Background = new SolidColorBrush(
            Color.FromArgb(38, textColor.R, textColor.G, textColor.B));
        // Glyph + label flip with the previewed variant: moon when showing
        // light (offer to preview dark), sun/brightness when showing dark.
        PreviewDarkLabel.Text = _previewDark ? "Preview light" : "Preview dark";
        PreviewDarkIcon.Glyph = _previewDark ? PreviewLightGlyph : PreviewDarkGlyph;
    }

    // Segoe Fluent Icons: E706 = Brightness (sun), E708 = QuietHours (moon).
    private const string PreviewDarkGlyph = "";
    private const string PreviewLightGlyph = "";

    private void OnTogglePreviewDark(object sender, RoutedEventArgs e)
    {
        _previewDark = !_previewDark;
        UpdateThemeDisplay();
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
        var window = new WhyExistWindow(_themes[_selectedIndex], centered: true, previewDark: _previewDark);
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
        var isDark = _previewDark;
        var fg = theme.OnBackgroundText(isDark);
        var fgBrush = new SolidColorBrush(fg);

        // Text colors
        FlowTitle.Foreground = fgBrush;
        FlowIcon.Foreground = fgBrush;
        BackLabel.Foreground = new SolidColorBrush(fg) { Opacity = 0.7 };
        FlowDescLabel.Foreground = fgBrush;

        // Explore button: capsule background (fg at 20% opacity, matching macOS)
        ExploreButton.Foreground = fgBrush;
        ExploreButton.Background = new SolidColorBrush(
            Color.FromArgb(50, fg.R, fg.G, fg.B));

        // Get Started button
        GetStartedButton.Background = fgBrush;
        GetStartedButton.Foreground = new SolidColorBrush(theme.BackgroundTop(isDark));

        UpdatePresetSelection();
    }

    private void OnBackToThemes(object sender, RoutedEventArgs e)
    {
        ShowThemePage();
    }

    private void OnPresetSelected(object sender, RoutedEventArgs e)
    {
        if (sender is Button btn && btn.Tag is string tag)
        {
            _selectedPreset = tag;
            _sensitivity = PresetToValue(tag);
            _themeManager.FlowSensitivity = _sensitivity;
            UpdatePresetSelection();
        }
    }

    private void UpdatePresetSelection()
    {
        var theme = _themes[_selectedIndex];
        var isDark = _previewDark;
        var fg = theme.OnBackgroundText(isDark);
        var accent = theme.Accent(isDark);

        // Update card backgrounds — selected gets white, others get translucent fg
        var unselectedBg = Color.FromArgb(40, fg.R, fg.G, fg.B);
        CardEyeHealth.Background = new SolidColorBrush(
            _selectedPreset == "eyeHealth" ? Colors.White : unselectedBg);
        CardBalanced.Background = new SolidColorBrush(
            _selectedPreset == "balanced" ? Colors.White : unselectedBg);
        CardDeepWork.Background = new SolidColorBrush(
            _selectedPreset == "deepWork" ? Colors.White : unselectedBg);

        // Selected card: accent for icon/name, accent at 80% for description
        // Unselected card: fg for icon/name, fg at 80% for description
        var accentBrush = new SolidColorBrush(accent);
        var accentDimBrush = new SolidColorBrush(accent) { Opacity = 0.8 };
        var fgBrush = new SolidColorBrush(fg);
        var fgDimBrush = new SolidColorBrush(fg) { Opacity = 0.8 };

        IconEyeHealth.Foreground = _selectedPreset == "eyeHealth" ? accentBrush : fgBrush;
        NameEyeHealth.Foreground = _selectedPreset == "eyeHealth" ? accentBrush : fgBrush;
        DescEyeHealth.Foreground = _selectedPreset == "eyeHealth" ? accentDimBrush : fgDimBrush;
        IconBalanced.Foreground = _selectedPreset == "balanced" ? accentBrush : fgBrush;
        NameBalanced.Foreground = _selectedPreset == "balanced" ? accentBrush : fgBrush;
        DescBalanced.Foreground = _selectedPreset == "balanced" ? accentDimBrush : fgDimBrush;
        IconDeepWork.Foreground = _selectedPreset == "deepWork" ? accentBrush : fgBrush;
        NameDeepWork.Foreground = _selectedPreset == "deepWork" ? accentBrush : fgBrush;
        DescDeepWork.Foreground = _selectedPreset == "deepWork" ? accentDimBrush : fgDimBrush;

        // Update description
        FlowDescLabel.Text = GetPresetDescription(_selectedPreset);
    }

    private void OnExploreHowItWorks(object sender, RoutedEventArgs e)
    {
        var theme = _themes[_selectedIndex];
        var window = new FlowLearnMoreWindow(theme, _sensitivity, centered: true, previewDark: _previewDark);
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
    // Single source of truth for preset values/labels lives in
    // FlowSensitivityPreset (Theme/) so onboarding + Settings stay in sync.

    private static double PresetToValue(string preset) => FlowSensitivityPreset.ValueFor(preset);

    private static string ClosestPreset(double sensitivity) => FlowSensitivityPreset.Closest(sensitivity);

    private static string GetPresetDescription(string preset) => FlowSensitivityPreset.Description(preset);
}
