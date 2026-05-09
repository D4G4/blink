using Microsoft.UI;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Media;
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
        bool isDark = Application.Current.RequestedTheme == ApplicationTheme.Dark;

        ThemeName.Text = theme.Name;
        PrevButton.IsEnabled = _selectedIndex > 0;
        NextButton.IsEnabled = _selectedIndex < _themes.Length - 1;

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

    private async void OnWhyExist(object sender, RoutedEventArgs e)
    {
        var dialog = new ContentDialog
        {
            Title = "Why do I exist?",
            Content = new StackPanel
            {
                Spacing = 16,
                Children =
                {
                    new TextBlock
                    {
                        Text = "The 20-20-20 Rule",
                        FontSize = 20,
                        FontWeight = Microsoft.UI.Text.FontWeights.Bold
                    },
                    new TextBlock
                    {
                        Text = "Every 20 minutes, look at something 20 feet away for 20 seconds.",
                        TextWrapping = TextWrapping.Wrap
                    },
                    new TextBlock
                    {
                        Text = "When you stare at a screen, your blink rate drops from 15 to 3-4 times per minute. " +
                               "This causes dry eyes, eye strain, and headaches. The 20-20-20 rule gives your eye muscles " +
                               "a chance to relax and your tear film to refresh.",
                        TextWrapping = TextWrapping.Wrap,
                        Opacity = 0.7
                    },
                    new TextBlock
                    {
                        Text = "How Blink Works",
                        FontSize = 20,
                        FontWeight = Microsoft.UI.Text.FontWeights.Bold,
                        Margin = new Thickness(0, 8, 0, 0)
                    },
                    new TextBlock
                    {
                        Text = "Blink monitors your keyboard and mouse activity to detect when you're in a flow state. " +
                               "When you're deeply focused, it extends the timer so you're not interrupted. " +
                               "When you step away, it auto-resets — no wasted breaks.",
                        TextWrapping = TextWrapping.Wrap,
                        Opacity = 0.7
                    }
                }
            },
            CloseButtonText = "Got it",
            XamlRoot = this.Content.XamlRoot
        };
        await dialog.ShowAsync();
    }
}
