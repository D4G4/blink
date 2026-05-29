using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Input;
using Microsoft.UI.Xaml.Media;
using Windows.System;
using Windows.UI;
using Blink.App.Theme;

namespace Blink.App.Onboarding;

public sealed partial class FlowLearnMoreWindow : Window
{
    private readonly BlinkTheme _theme;
    private readonly bool _isDark;
    private double _sensitivity;

    // `previewDark` is forwarded from onboarding (which always renders light and
    // carries its own preview-dark toggle) so this window doesn't jump to the
    // system appearance mid-flow. When opened from Settings the parameter is
    // omitted (null) and the window follows the system appearance as before.
    public FlowLearnMoreWindow(BlinkTheme theme, double sensitivity, bool centered = false, bool? previewDark = null)
    {
        _theme = theme;
        _isDark = previewDark ?? (Application.Current.RequestedTheme == ApplicationTheme.Dark);
        _sensitivity = sensitivity;

        InitializeComponent();
        AppWindow.SetIcon(Path.Combine(AppContext.BaseDirectory, "app.ico"));

        // Set Maximum before Minimum to avoid a WinUI 3 XAML-parse ordering bug
        // ("Failed to assign to property RangeBase.Minimum") in unpackaged apps.
        // Range 25–90% covers all three presets (Eye health 30% → Deep work 75%)
        // plus headroom for fine-tuning, matching the macOS slider (0.25–0.90).
        SensitivitySlider.Maximum = 90;
        SensitivitySlider.Minimum = 25;
        SensitivitySlider.StepFrequency = 5;

        var area = Microsoft.UI.Windowing.DisplayArea.Primary;
        var width = Math.Min(520, (int)(area.WorkArea.Width * 0.5));
        var height = Math.Min(700, (int)(area.WorkArea.Height * 0.85));
        var (x, y) = centered
            ? ((area.WorkArea.Width - width) / 2, (area.WorkArea.Height - height) / 2)
            : (area.WorkArea.X + area.WorkArea.Width - width - 12,
               area.WorkArea.Y + area.WorkArea.Height - height - 12);
        AppWindow.MoveAndResize(new Windows.Graphics.RectInt32(x, y, width, height));

        SensitivitySlider.Value = sensitivity * 100;
        ApplyTheme();
        BuildContent();

        if (Content is FrameworkElement root)
            root.KeyDown += OnKeyDown;
    }

    private static int GapTolerance(double sensitivity)
    {
        // Map the slider's 0.25–0.90 range to a 15–90s pause tolerance,
        // clamped so out-of-range values don't produce negative seconds.
        var t = Math.Clamp((sensitivity - 0.25) / (0.90 - 0.25), 0.0, 1.0);
        return (int)Math.Round(15 + t * 75);
    }

    private void ApplyTheme()
    {
        var accent = _theme.Accent(_isDark);
        var accentBrush = new SolidColorBrush(accent);

        HeaderIcon.Foreground = accentBrush;
        SensitivityLabel.Foreground = accentBrush;
        SensitivitySlider.Foreground = accentBrush;
        GotItButton.Background = accentBrush;

        var pct = (int)(_sensitivity * 100);
        SensitivityLabel.Text = $"Sensitivity: {pct}%";
    }

    private void BuildContent()
    {
        ContentPanel.Children.Clear();

        var accent = _theme.Accent(_isDark);
        var accentBrush = new SolidColorBrush(accent);
        var faintBg = new SolidColorBrush(Color.FromArgb(15, 128, 128, 128));
        var gap = GapTolerance(_sensitivity);
        var pct = (int)(_sensitivity * 100);

        // Section: The simple rule
        AddSectionHeader("The simple rule");
        AddParagraph("If you've been continuously active \u2014 any keyboard or mouse input \u2014 with no long pauses, Blink considers you in flow and extends your break interval.");

        // Section: How it decides
        AddSectionHeader("How it decides");
        var rulesPanel = new StackPanel { Spacing = 6 };
        AddRuleRow(rulesPanel, "Active for 3+ minutes", "\u2192 Flow (breaks at 30 min)", accentBrush);
        AddRuleRow(rulesPanel, "In flow for 15+ minutes", "\u2192 Deep Flow (breaks at 40 min)", accentBrush);
        AddRuleRow(rulesPanel, $"Pause > {gap}s", "\u2192 Flow ends, back to 20 min", accentBrush);
        var rulesBorder = new Border
        {
            Background = faintBg,
            CornerRadius = new CornerRadius(10),
            Padding = new Thickness(14),
            Child = rulesPanel
        };
        ContentPanel.Children.Add(rulesBorder);

        // Section: Real scenarios
        AddSectionHeader($"Real scenarios at {pct}%");

        var thinkingPause = gap - 10;
        var readingPause = gap + 15;
        var switchGap = Math.Max(gap - 20, 5);

        AddScenarioCard("\uE92E", // keyboard
            $"Coding with {thinkingPause}s thinking pauses",
            $"You type, pause {thinkingPause}s to think, type again. Gap ({thinkingPause}s) is under your {gap}s tolerance.",
            "Flow stays active \u2014 timer extends to 30\u201340 min",
            accentBrush, faintBg);

        AddScenarioCard("\uE8A5", // document
            $"Reading docs for {readingPause}s",
            $"You read without input for {readingPause}s, then start typing. Gap ({readingPause}s) exceeds your {gap}s tolerance.",
            "Flow breaks. Timer resets to 20 min",
            accentBrush, faintBg);

        AddScenarioCard("\uE8AB", // switch
            $"Switching apps every {switchGap}s",
            $"You switch between editor and browser, clicking every {switchGap}s. All gaps under {gap}s.",
            "Flow stays active \u2014 based on input gaps, not which app",
            accentBrush, faintBg);

        AddScenarioCard("\uED63", // coffee/cup
            "Getting coffee (away 5 min)",
            $"No input for 5 minutes. Exceeds both {gap}s tolerance and 3 min idle threshold.",
            "Timer resets silently \u2014 you already rested your eyes",
            accentBrush, faintBg);

        AddScenarioCard("\uE720", // microphone
            "On a call",
            "Mic active. Detected immediately regardless of sensitivity.",
            "Timer pauses. Resumes when call ends",
            accentBrush, faintBg);

        AddScenarioCard("\uE945", // brain
            "Deep in flow, timer fires",
            "You've been coding for 40 min straight. Timer reaches zero.",
            "Gentle toast \u2014 never forces overlay during flow",
            accentBrush, faintBg);

        AddScenarioCard("\uE8FB", // hand
            "Not in flow, timer fires",
            "Browsing casually for 20 min. Timer reaches zero.",
            "Fullscreen break \u2014 20s. Esc to skip, \u2192 to extend",
            accentBrush, faintBg);

        // Section: Break intervals
        AddSectionHeader("Break intervals");
        var timerGrid = new Grid { ColumnSpacing = 0 };
        timerGrid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
        timerGrid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
        timerGrid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
        AddTimerColumn(timerGrid, 0, "Normal", "20 min", "Default", accentBrush);
        AddTimerColumn(timerGrid, 1, "Flow", "30 min", "3+ min active", accentBrush);
        AddTimerColumn(timerGrid, 2, "Deep Flow", "40 min", "15+ min active", accentBrush);
        var timerBorder = new Border
        {
            Background = faintBg,
            CornerRadius = new CornerRadius(10),
            Padding = new Thickness(14),
            Child = timerGrid
        };
        ContentPanel.Children.Add(timerBorder);

        // Privacy notice
        var privacyRow = new StackPanel
        {
            Orientation = Orientation.Horizontal,
            Spacing = 10,
            Children =
            {
                new FontIcon { Glyph = "\uE72E", FontSize = 16, Foreground = accentBrush,
                               VerticalAlignment = VerticalAlignment.Center },
                new TextBlock
                {
                    Text = "Blink reads input timing only \u2014 never keystrokes, window contents, or personal data.",
                    FontSize = 12, FontWeight = Microsoft.UI.Text.FontWeights.Medium,
                    TextWrapping = TextWrapping.Wrap
                }
            }
        };
        var privacyBorder = new Border
        {
            Background = new SolidColorBrush(Color.FromArgb(20, accent.R, accent.G, accent.B)),
            CornerRadius = new CornerRadius(10),
            Padding = new Thickness(12),
            Margin = new Thickness(0, 4, 0, 0),
            Child = privacyRow
        };
        ContentPanel.Children.Add(privacyBorder);
    }

    private void AddSectionHeader(string title)
    {
        ContentPanel.Children.Add(new TextBlock
        {
            Text = title,
            FontSize = 14,
            FontWeight = Microsoft.UI.Text.FontWeights.Bold,
            Margin = new Thickness(0, 4, 0, 0)
        });
    }

    private void AddParagraph(string text)
    {
        ContentPanel.Children.Add(new TextBlock
        {
            Text = text,
            FontSize = 13,
            TextWrapping = TextWrapping.Wrap
        });
    }

    private static void AddRuleRow(StackPanel parent, string condition, string result, Brush accent)
    {
        var row = new StackPanel
        {
            Orientation = Orientation.Horizontal,
            Spacing = 8,
            Children =
            {
                new TextBlock { Text = condition, FontSize = 12, FontWeight = Microsoft.UI.Text.FontWeights.Bold },
                new TextBlock { Text = result, FontSize = 12 }
            }
        };
        parent.Children.Add(row);
    }

    private void AddScenarioCard(string glyph, string title, string detail, string result,
                                  Brush accentBrush, Brush faintBg)
    {
        var iconBorder = new Border
        {
            Width = 24, Height = 24,
            CornerRadius = new CornerRadius(5),
            Background = new SolidColorBrush(Color.FromArgb(38,
                ((SolidColorBrush)accentBrush).Color.R,
                ((SolidColorBrush)accentBrush).Color.G,
                ((SolidColorBrush)accentBrush).Color.B)),
            Child = new FontIcon
            {
                Glyph = glyph, FontSize = 13, Foreground = accentBrush,
                HorizontalAlignment = HorizontalAlignment.Center,
                VerticalAlignment = VerticalAlignment.Center
            }
        };

        var resultRow = new StackPanel
        {
            Orientation = Orientation.Horizontal,
            Spacing = 4,
            Children =
            {
                new FontIcon { Glyph = "\uE72A", FontSize = 9, Foreground = accentBrush,
                               VerticalAlignment = VerticalAlignment.Center },
                new TextBlock { Text = result, FontSize = 12,
                                FontWeight = Microsoft.UI.Text.FontWeights.SemiBold,
                                Foreground = accentBrush, TextWrapping = TextWrapping.Wrap }
            }
        };

        var card = new Border
        {
            Background = faintBg,
            CornerRadius = new CornerRadius(8),
            Padding = new Thickness(12),
            Child = new StackPanel
            {
                Spacing = 6,
                Children =
                {
                    new StackPanel
                    {
                        Orientation = Orientation.Horizontal,
                        Spacing = 8,
                        Children =
                        {
                            iconBorder,
                            new TextBlock { Text = title, FontSize = 13,
                                            FontWeight = Microsoft.UI.Text.FontWeights.Bold,
                                            VerticalAlignment = VerticalAlignment.Center,
                                            TextWrapping = TextWrapping.Wrap }
                        }
                    },
                    new TextBlock { Text = detail, FontSize = 12, TextWrapping = TextWrapping.Wrap },
                    resultRow
                }
            }
        };
        ContentPanel.Children.Add(card);
    }

    private static void AddTimerColumn(Grid parent, int col, string label, string duration, string description, Brush accent)
    {
        var stack = new StackPanel
        {
            Spacing = 4,
            HorizontalAlignment = HorizontalAlignment.Center,
            Children =
            {
                new TextBlock { Text = duration, FontSize = 18,
                                FontWeight = Microsoft.UI.Text.FontWeights.Bold,
                                Foreground = accent, HorizontalAlignment = HorizontalAlignment.Center },
                new TextBlock { Text = label, FontSize = 12,
                                FontWeight = Microsoft.UI.Text.FontWeights.SemiBold,
                                HorizontalAlignment = HorizontalAlignment.Center },
                new TextBlock { Text = description, FontSize = 10, Opacity = 0.6,
                                HorizontalAlignment = HorizontalAlignment.Center }
            }
        };
        Grid.SetColumn(stack, col);
        parent.Children.Add(stack);
    }

    private void SensitivitySlider_ValueChanged(object sender, Microsoft.UI.Xaml.Controls.Primitives.RangeBaseValueChangedEventArgs e)
    {
        var pct = (int)e.NewValue;
        _sensitivity = pct / 100.0;
        ThemeManager.Instance.FlowSensitivity = _sensitivity;

        var accent = _theme.Accent(_isDark);
        SensitivityLabel.Text = $"Sensitivity: {pct}%";
        SensitivityLabel.Foreground = new SolidColorBrush(accent);

        BuildContent();
    }

    private void OnGotIt(object sender, RoutedEventArgs e) => Close();

    private void OnKeyDown(object sender, KeyRoutedEventArgs e)
    {
        if (e.Key == VirtualKey.Escape) { Close(); e.Handled = true; }
    }
}
