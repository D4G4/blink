using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Input;
using Microsoft.UI.Xaml.Media;
using Windows.System;
using Windows.UI;
using Blink.App.Theme;

namespace Blink.App.Onboarding;

public sealed partial class WhyExistWindow : Window
{
    // Segoe Fluent Icons glyphs
    private const string GlyphClock = "";
    private const string GlyphPause = "";
    private const string GlyphEye = "";
    private const string GlyphWarning = "";
    private const string GlyphEyeWarning = "";
    private const string GlyphCheck = "";
    private const string GlyphSparkles = "";
    private const string GlyphBrain = "";
    private const string GlyphHand = "";
    private const string GlyphWalk = "";
    private const string GlyphVideo = "";
    private const string GlyphMeeting = "";

    private readonly BlinkTheme _theme;
    private readonly bool _isDark;
    private SolidColorBrush _fgBrush = null!;
    private int _page;

    public WhyExistWindow(BlinkTheme theme)
    {
        _theme = theme;
        _isDark = Application.Current.RequestedTheme == ApplicationTheme.Dark;
        InitializeComponent();
        AppWindow.SetIcon(Path.Combine(AppContext.BaseDirectory, "app.ico"));

        var area = Microsoft.UI.Windowing.DisplayArea.Primary;
        var width = Math.Min(720, (int)(area.WorkArea.Width * 0.7));
        var height = Math.Min(720, (int)(area.WorkArea.Height * 0.85));
        AppWindow.Resize(new Windows.Graphics.SizeInt32(width, height));
        AppWindow.Move(new Windows.Graphics.PointInt32(
            (area.WorkArea.Width - width) / 2,
            (area.WorkArea.Height - height) / 2));

        ApplyThemeBackground();
        BuildPage1();
        BuildPage2();
        UpdatePageVisibility();

        if (Content is FrameworkElement root)
        {
            root.KeyDown += OnKeyDown;
        }
    }

    private void ApplyThemeBackground()
    {
        var top = _theme.BackgroundTop(_isDark);
        var bottom = _theme.BackgroundBottom(_isDark);
        RootGrid.Background = new LinearGradientBrush
        {
            StartPoint = new Windows.Foundation.Point(0, 0),
            EndPoint = new Windows.Foundation.Point(0, 1),
            GradientStops =
            {
                new GradientStop { Color = top, Offset = 0 },
                new GradientStop { Color = bottom, Offset = 1 }
            }
        };

        var accent = _theme.Accent(_isDark);
        GotItButton.Background = new SolidColorBrush(accent);
        GotItButton.Foreground = new SolidColorBrush(_theme.TextOnAccent(_isDark));
        NextLabel.Foreground = new SolidColorBrush(accent);
        NextChevron.Foreground = new SolidColorBrush(accent);

        var textColor = _theme.OnBackgroundText(_isDark);
        Dot1.Fill = new SolidColorBrush(textColor);
        Dot2.Fill = new SolidColorBrush(textColor);

        _fgBrush = new SolidColorBrush(textColor);
        Page1Title.Foreground = _fgBrush;
        Page1Subtitle.Foreground = _fgBrush;
        Page2Title.Foreground = _fgBrush;
        Page2Subtitle.Foreground = _fgBrush;
    }

    private void BuildPage1()
    {
        var accent = _theme.Accent(_isDark);
        var accentBrush = new SolidColorBrush(accent);
        var faintAccent = new SolidColorBrush(Color.FromArgb(20, accent.R, accent.G, accent.B));

        RuleCardsRow.Children.Clear();
        AddRuleCard(0, GlyphClock, "20", "min", "Every 20 minutes\nof screen time", faintAccent, accentBrush);
        AddRuleCard(1, GlyphPause, "20", "sec", "Take a 20-second\nbreak", faintAccent, accentBrush);
        AddRuleCard(2, GlyphEye, "20", "feet", "Look at something\n20 feet away", faintAccent, accentBrush);

        FactsList.Children.Clear();
        AddFactRow(GlyphWarning, "Your blink rate drops from 15/min to 4/min during screen work", accentBrush);
        AddFactRow(GlyphEyeWarning, "This causes dry eyes, headaches, and blurred vision", accentBrush);
        AddFactRow(GlyphCheck, "A 20-second break lets your eye muscles relax and reset", accentBrush);
        AddFactRow(GlyphSparkles, "Blink detects your work patterns so breaks come at the right time", accentBrush);
    }

    private void BuildPage2()
    {
        var accent = new SolidColorBrush(_theme.Accent(_isDark));

        FeaturesList.Children.Clear();
        AddFeatureRow(GlyphBrain, "Flow detection",
            "Monitors your typing rhythm and app switching to detect deep focus. Extends the timer so you're not interrupted mid-thought.", accent);
        AddFeatureRow(GlyphHand, "Natural pause waiting",
            "When you're focused, Blink waits for a natural pause before prompting — no jarring mid-keystroke popups.", accent);
        AddFeatureRow(GlyphWalk, "Walk-away detection",
            "Step away from your computer? Blink counts that as a break and silently resets the timer.", accent);
        AddFeatureRow(GlyphVideo, "Video awareness",
            "Detects when you're watching video and pauses — you're already resting your focus.", accent);
        AddFeatureRow(GlyphMeeting, "Meeting detection",
            "Pauses automatically during calls so you're never interrupted in a meeting.", accent);
    }

    private void AddRuleCard(int col, string glyph, string number, string unit, string description, Brush bg, Brush accent)
    {
        var card = new Border
        {
            Background = bg,
            CornerRadius = new CornerRadius(12),
            Padding = new Thickness(16, 20, 16, 20),
            Child = new StackPanel
            {
                Spacing = 10,
                HorizontalAlignment = HorizontalAlignment.Center,
                Children =
                {
                    new FontIcon { Glyph = glyph, FontSize = 28, Foreground = accent },
                    new StackPanel
                    {
                        Orientation = Orientation.Horizontal,
                        Spacing = 3,
                        HorizontalAlignment = HorizontalAlignment.Center,
                        Children =
                        {
                            new TextBlock { Text = number, FontSize = 42, FontWeight = Microsoft.UI.Text.FontWeights.Bold, Foreground = _fgBrush },
                            new TextBlock { Text = unit, FontSize = 16, FontWeight = Microsoft.UI.Text.FontWeights.Medium,
                                            Foreground = _fgBrush, Opacity = 0.6, VerticalAlignment = VerticalAlignment.Bottom, Margin = new Thickness(0,0,0,8) }
                        }
                    },
                    new TextBlock
                    {
                        Text = description,
                        FontSize = 14,
                        Foreground = _fgBrush,
                        Opacity = 0.7,
                        TextAlignment = TextAlignment.Center,
                        TextWrapping = TextWrapping.Wrap
                    }
                }
            }
        };
        Grid.SetColumn(card, col);
        RuleCardsRow.Children.Add(card);
    }

    private void AddFactRow(string glyph, string text, Brush accent)
    {
        var row = new StackPanel
        {
            Orientation = Orientation.Horizontal,
            Spacing = 12,
            Children =
            {
                new FontIcon { Glyph = glyph, FontSize = 16, Foreground = accent, Width = 22, VerticalAlignment = VerticalAlignment.Top, Margin = new Thickness(0,2,0,0) },
                new TextBlock { Text = text, FontSize = 15, Foreground = _fgBrush, TextWrapping = TextWrapping.Wrap }
            }
        };
        FactsList.Children.Add(row);
    }

    private void AddFeatureRow(string glyph, string title, string description, Brush accent)
    {
        var row = new Grid { ColumnSpacing = 14 };
        row.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(28) });
        row.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });

        var icon = new FontIcon { Glyph = glyph, FontSize = 20, Foreground = accent, VerticalAlignment = VerticalAlignment.Top, Margin = new Thickness(0,2,0,0) };
        Grid.SetColumn(icon, 0);
        row.Children.Add(icon);

        var stack = new StackPanel
        {
            Spacing = 4,
            Children =
            {
                new TextBlock { Text = title, FontSize = 16, FontWeight = Microsoft.UI.Text.FontWeights.SemiBold, Foreground = _fgBrush },
                new TextBlock { Text = description, FontSize = 14, Foreground = _fgBrush, Opacity = 0.7, TextWrapping = TextWrapping.Wrap }
            }
        };
        Grid.SetColumn(stack, 1);
        row.Children.Add(stack);

        FeaturesList.Children.Add(row);
    }

    private void UpdatePageVisibility()
    {
        Page1.Visibility = _page == 0 ? Visibility.Visible : Visibility.Collapsed;
        Page2.Visibility = _page == 1 ? Visibility.Visible : Visibility.Collapsed;
        BackButton.Visibility = _page == 1 ? Visibility.Visible : Visibility.Collapsed;
        NextButton.Visibility = _page == 0 ? Visibility.Visible : Visibility.Collapsed;
        GotItButton.Visibility = _page == 1 ? Visibility.Visible : Visibility.Collapsed;
        Dot1.Opacity = _page == 0 ? 1.0 : 0.3;
        Dot2.Opacity = _page == 1 ? 1.0 : 0.3;
    }

    private void OnNext(object sender, RoutedEventArgs e) { _page = 1; UpdatePageVisibility(); }
    private void OnBack(object sender, RoutedEventArgs e) { _page = 0; UpdatePageVisibility(); }
    private void OnGotIt(object sender, RoutedEventArgs e) => Close();

    private void OnKeyDown(object sender, KeyRoutedEventArgs e)
    {
        if (e.Key == VirtualKey.Escape) { Close(); e.Handled = true; }
        else if (e.Key == VirtualKey.Left && _page == 1) { _page = 0; UpdatePageVisibility(); e.Handled = true; }
        else if (e.Key == VirtualKey.Right && _page == 0) { _page = 1; UpdatePageVisibility(); e.Handled = true; }
    }
}
