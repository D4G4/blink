using Microsoft.UI.Xaml;
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
        ThemeName.Text = theme.Name;
        PrevButton.IsEnabled = _selectedIndex > 0;
        NextButton.IsEnabled = _selectedIndex < _themes.Length - 1;

        // TODO: Update background gradient and icon from theme assets
    }

    private void OnPrevious(object sender, RoutedEventArgs e)
    {
        if (_selectedIndex > 0)
        {
            _selectedIndex--;
            UpdateThemeDisplay();
        }
    }

    private void OnNext(object sender, RoutedEventArgs e)
    {
        if (_selectedIndex < _themes.Length - 1)
        {
            _selectedIndex++;
            UpdateThemeDisplay();
        }
    }

    private void OnGetStarted(object sender, RoutedEventArgs e)
    {
        _themeManager.Select(_themes[_selectedIndex]);
        _themeManager.HasCompletedOnboarding = true;
        Close();
    }

    private void OnWhyExist(object sender, RoutedEventArgs e)
    {
        // TODO: Show "Why do I exist?" dialog with 20-20-20 rule education
    }
}
