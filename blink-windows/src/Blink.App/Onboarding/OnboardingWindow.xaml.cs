using Microsoft.UI;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Media;
using Microsoft.UI.Xaml.Media.Imaging;
using Blink.App.Theme;

namespace Blink.App.Onboarding;

public sealed partial class OnboardingWindow : Window
{
    private readonly ThemeManager _themeManager;
    private int _selectedIndex;
    private readonly BlinkTheme[] _themes = BlinkTheme.All;

    public OnboardingWindow(ThemeManager themeManager)
    {
        _themeManager = themeManager;
        InitializeComponent();
        AppWindow.SetIcon(Path.Combine(AppContext.BaseDirectory, "app.ico"));

        // Start with Peach (or Midnight if system is dark)
        // WinUI dark mode detection:
        var isDark = Application.Current.RequestedTheme == ApplicationTheme.Dark;
        _selectedIndex = isDark
            ? Array.FindIndex(_themes, t => t.Id == "midnight")
            : Array.FindIndex(_themes, t => t.Id == "peach");
        if (_selectedIndex < 0) _selectedIndex = 0;

        UpdateThemeDisplay();

        // Set window size to 80% of screen
        var area = Microsoft.UI.Windowing.DisplayArea.Primary;
        var width = (int)(area.WorkArea.Width * 0.8);
        var height = (int)(area.WorkArea.Height * 0.8);
        AppWindow.Resize(new Windows.Graphics.SizeInt32(width, height));
        AppWindow.Move(new Windows.Graphics.PointInt32(
            (area.WorkArea.Width - width) / 2,
            (area.WorkArea.Height - height) / 2));
    }

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

    private void OnGetStarted(object sender, RoutedEventArgs e)
    {
        _themeManager.Select(_themes[_selectedIndex]);
        _themeManager.HasCompletedOnboarding = true;
        Close();
    }

    private void OnWhyExist(object sender, RoutedEventArgs e)
    {
        var window = new WhyExistWindow(_themes[_selectedIndex]);
        window.Activate();
    }
}
