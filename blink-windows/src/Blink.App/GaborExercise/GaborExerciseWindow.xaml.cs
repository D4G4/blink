using System.ComponentModel;
using System.IO;
using Microsoft.UI.Dispatching;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Input;
using Microsoft.UI.Xaml.Media;
using Microsoft.UI.Xaml.Media.Imaging;
using Windows.UI;
using Microsoft.UI;
using Blink.App.Theme;
using Ellipse = Microsoft.UI.Xaml.Shapes.Ellipse;
using Rectangle = Microsoft.UI.Xaml.Shapes.Rectangle;

namespace Blink.App.GaborExercise;

public sealed partial class GaborExerciseWindow : Window
{
    private readonly GaborExerciseState _state;
    private readonly BlinkTheme _theme;
    private readonly bool _isDark;
    private readonly GaborDisplayConfig _config;
    private readonly DispatcherQueue _dispatcher;

    public GaborExerciseWindow(BlinkTheme theme)
    {
        _theme = theme;
        _isDark = Application.Current.RequestedTheme == ApplicationTheme.Dark;
        _config = GaborDisplayConfig.Current();
        _state = new GaborExerciseState();
        _dispatcher = DispatcherQueue.GetForCurrentThread();
        _state.PostToUi = action => _dispatcher.TryEnqueue(() => action());

        InitializeComponent();
        AppWindow.SetIcon(Path.Combine(AppContext.BaseDirectory, "app.ico"));
        Title = "Eye Exercise";

        // Matches macOS toggleFullScreen — hides title bar + taskbar, covers entire screen.
        AppWindow.SetPresenter(Microsoft.UI.Windowing.AppWindowPresenterKind.FullScreen);

        _state.PropertyChanged += OnStateChanged;
        Closed += (_, _) =>
        {
            _state.PropertyChanged -= OnStateChanged;
            _state.CancelSession();
        };

        // PreviewKeyDown (tunneling) fires before a focused response button can
        // consume an arrow key for focus navigation, so ← / → reliably reach
        // the trial handler regardless of which control has focus.
        if (Content is FrameworkElement root)
            root.PreviewKeyDown += OnKeyDown;

        Render();
    }

    private void OnStateChanged(object? sender, PropertyChangedEventArgs e)
    {
        if (e.PropertyName is nameof(GaborExerciseState.Phase) or
            nameof(GaborExerciseState.CurrentTrial) or
            nameof(GaborExerciseState.Score) or
            nameof(GaborExerciseState.TargetPosition) or
            nameof(GaborExerciseState.TargetOrientation) or
            nameof(GaborExerciseState.FlankerDistanceLevel) or
            nameof(GaborExerciseState.ExerciseType))
        {
            _dispatcher.TryEnqueue(Render);
        }
    }

    private void OnKeyDown(object sender, KeyRoutedEventArgs e)
    {
        switch (e.Key)
        {
            // ← / → submit the left/right (or tilted-left/right) response, but
            // only during a live trial. Mirrors the macOS .keyboardShortcut
            // bindings: left arrow → response 0, right arrow → response 1.
            case Windows.System.VirtualKey.Left when _state.Phase == ExercisePhase.Presenting:
                _state.SubmitResponse(0);
                e.Handled = true;
                break;
            case Windows.System.VirtualKey.Right when _state.Phase == ExercisePhase.Presenting:
                _state.SubmitResponse(1);
                e.Handled = true;
                break;

            // Esc steps back to the picker from a trial, its feedback, or the
            // instructions — abandoning the in-progress attempt without saving.
            // From the picker/disclaimer/results it closes the window.
            case Windows.System.VirtualKey.Escape:
                if (_state.Phase is ExercisePhase.Presenting
                    or ExercisePhase.FeedbackCorrect
                    or ExercisePhase.FeedbackIncorrect
                    or ExercisePhase.Instructions)
                {
                    _state.ReturnToPicker();
                }
                else
                {
                    Close();
                }
                e.Handled = true;
                break;
        }
    }

    private void OnShowDisclaimer(object sender, RoutedEventArgs e) => _state.ShowDisclaimer();
    private void OnCloseClick(object sender, RoutedEventArgs e) => Close();

    private void Render()
    {
        // The Gabor stimulus is only on screen during a trial; only then do we
        // switch to the mid-gray field a patch must sit on, so its
        // Gaussian-tapered edges blend into the surround instead of reading as
        // a hard disc against black. The picker, instructions, disclaimer, and
        // results keep the dark look.
        RootGrid.Background = OnGray ? MidGrayBrush : new SolidColorBrush(Colors.Black);

        // Footer (lives outside PhaseHost, spans every phase): dark text on the
        // mid-gray field, white on the dark phases.
        var footerFg = OnGray ? TrialFg : new SolidColorBrush(Colors.White);
        FooterText.Foreground = footerFg;
        FooterDisclaimer.Foreground = footerFg;
        FooterClose.Foreground = footerFg;

        PhaseHost.Content = _state.Phase switch
        {
            ExercisePhase.Disclaimer => BuildDisclaimer(),
            ExercisePhase.Ready => BuildReady(),
            ExercisePhase.Instructions => BuildInstructions(),
            ExercisePhase.Presenting => BuildTrial(false, false),
            ExercisePhase.FeedbackCorrect => BuildTrial(true, true),
            ExercisePhase.FeedbackIncorrect => BuildTrial(true, false),
            ExercisePhase.Complete => BuildComplete(),
            _ => new TextBlock { Text = "?" }
        };
    }

    private bool OnGray => _state.Phase is ExercisePhase.Presenting
        or ExercisePhase.FeedbackCorrect
        or ExercisePhase.FeedbackIncorrect;

    // ── Common brushes ──

    // Mid-gray field matched to the Gabor patch's mean luminance (0.5 → 128).
    private static SolidColorBrush MidGrayBrush => new(Color.FromArgb(255, 128, 128, 128));
    // Dark text/icon foreground for use on the mid-gray field (macOS white: 0.12 ≈ 31).
    private static SolidColorBrush TrialFg => new(Color.FromArgb(255, 31, 31, 31));

    private SolidColorBrush Fg => new(Colors.White);
    private SolidColorBrush Accent => new(_theme.Accent(_isDark));
    private SolidColorBrush AccentSoft => new(Color.FromArgb(38, _theme.Accent(_isDark).R, _theme.Accent(_isDark).G, _theme.Accent(_isDark).B));
    private SolidColorBrush FgSoft(int alpha) => new(Color.FromArgb((byte)alpha, 255, 255, 255));

    // ── Phase builders ──

    private FrameworkElement BuildDisclaimer()
    {
        var sp = new StackPanel { Spacing = 28, HorizontalAlignment = HorizontalAlignment.Center, VerticalAlignment = VerticalAlignment.Center, MaxWidth = 600, Padding = new Thickness(40) };
        sp.Children.Add(new FontIcon { Glyph = "", FontSize = 48, Foreground = Fg });
        sp.Children.Add(new TextBlock { Text = "Before You Start", FontSize = 28, FontWeight = Microsoft.UI.Text.FontWeights.SemiBold, Foreground = Fg, HorizontalAlignment = HorizontalAlignment.Center });
        sp.Children.Add(new TextBlock
        {
            Text = "This exercise is for general wellness and entertainment purposes only. " +
                   "It is not a medical device, does not diagnose or treat any condition, " +
                   "and is not a substitute for professional eye care.\n\n" +
                   "Consult an eye care professional before starting any vision training " +
                   "program. Results may vary. If you experience discomfort, stop immediately.",
            FontSize = 18, LineHeight = 26,
            Foreground = Fg, TextAlignment = TextAlignment.Center, TextWrapping = TextWrapping.Wrap, MaxWidth = 600
        });
        var btn = AccentButton("I Understand", 180, () => _state.AcceptDisclaimer());
        sp.Children.Add(btn);
        return sp;
    }

    private FrameworkElement BuildReady()
    {
        var root = new StackPanel { Spacing = 0, HorizontalAlignment = HorizontalAlignment.Center, VerticalAlignment = VerticalAlignment.Center, Padding = new Thickness(40) };

        root.Children.Add(new TextBlock { Text = "Eye Exercise", FontSize = 32, FontWeight = Microsoft.UI.Text.FontWeights.Bold, Foreground = Fg, HorizontalAlignment = HorizontalAlignment.Center, Margin = new Thickness(0, 0, 0, 8) });
        root.Children.Add(new TextBlock { Text = "Train your visual cortex with Gabor patch exercises", FontSize = 15, Foreground = Fg, HorizontalAlignment = HorizontalAlignment.Center, Margin = new Thickness(0, 0, 0, 40) });

        var cards = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 20, HorizontalAlignment = HorizontalAlignment.Center };
        foreach (var t in Enum.GetValues<ExerciseType>())
        {
            cards.Children.Add(BuildExerciseCard(t));
        }
        root.Children.Add(cards);

        root.Children.Add(new Border { Height = 40 });
        root.Children.Add(AccentButton("Continue", 180, () => _state.ShowInstructions()));
        return root;
    }

    private FrameworkElement BuildExerciseCard(ExerciseType t)
    {
        var selected = _state.ExerciseType == t;
        var inner = new StackPanel { Spacing = 14, HorizontalAlignment = HorizontalAlignment.Center, VerticalAlignment = VerticalAlignment.Center };
        inner.Children.Add(new FontIcon { Glyph = t.IconGlyph(), FontSize = 28, Foreground = selected ? Accent : Fg, Height = 36 });
        inner.Children.Add(new TextBlock { Text = t.DisplayName(), FontSize = 14, FontWeight = Microsoft.UI.Text.FontWeights.SemiBold, Foreground = Fg, HorizontalAlignment = HorizontalAlignment.Center });
        inner.Children.Add(new TextBlock
        {
            Text = t.Headline(), FontSize = 12, Foreground = Fg,
            TextAlignment = TextAlignment.Center, TextWrapping = TextWrapping.Wrap,
            HorizontalAlignment = HorizontalAlignment.Center
        });

        var btn = new Button
        {
            Width = 220, Height = 140,
            Background = FgSoft(selected ? 51 : 26),
            BorderBrush = selected ? Accent : new SolidColorBrush(Colors.Transparent),
            BorderThickness = new Thickness(2),
            CornerRadius = new CornerRadius(14),
            Padding = new Thickness(8),
            Content = inner
        };
        btn.Click += (_, _) => { _state.ExerciseType = t; };
        return btn;
    }

    private FrameworkElement BuildInstructions()
    {
        var t = _state.ExerciseType;
        var root = new StackPanel { Spacing = 0, HorizontalAlignment = HorizontalAlignment.Center, VerticalAlignment = VerticalAlignment.Center, Padding = new Thickness(40), MaxWidth = 640 };

        root.Children.Add(new FontIcon { Glyph = t.IconGlyph(), FontSize = 52, Foreground = Accent, Margin = new Thickness(0, 0, 0, 20), HorizontalAlignment = HorizontalAlignment.Center });
        root.Children.Add(new TextBlock { Text = t.DisplayName(), FontSize = 34, FontWeight = Microsoft.UI.Text.FontWeights.Bold, Foreground = Fg, HorizontalAlignment = HorizontalAlignment.Center, Margin = new Thickness(0, 0, 0, 6) });
        root.Children.Add(new TextBlock { Text = t.Headline(), FontSize = 20, FontWeight = Microsoft.UI.Text.FontWeights.Medium, Foreground = Fg, HorizontalAlignment = HorizontalAlignment.Center, Margin = new Thickness(0, 0, 0, 36) });

        var card = new StackPanel { Spacing = 24 };
        card.Children.Add(BuildInfoSection("", "What is this?", t.Explanation()));
        card.Children.Add(new Rectangle { Height = 1, Fill = FgSoft(38) });
        card.Children.Add(BuildInfoSection("", "How to play", t.HowToPlay()));
        card.Children.Add(new Rectangle { Height = 1, Fill = FgSoft(38) });
        card.Children.Add(BuildInfoSection("", "Adaptive difficulty",
            "The pattern gets fainter as you answer correctly, and bolder when you make mistakes. " +
            "The exercise zeroes in on your contrast threshold — the faintest level you can reliably detect."));

        var border = new Border
        {
            Background = FgSoft(26),
            CornerRadius = new CornerRadius(14),
            Padding = new Thickness(28),
            Child = card
        };
        root.Children.Add(border);

        root.Children.Add(new Border { Height = 36 });

        var buttonRow = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 16, HorizontalAlignment = HorizontalAlignment.Center };
        buttonRow.Children.Add(SecondaryButton("Back", 100, () => _state.Phase = ExercisePhase.Ready));
        buttonRow.Children.Add(AccentButton($"Start {_state.TotalTrials} Trials", 180, () => _state.StartExercise()));
        root.Children.Add(buttonRow);
        return root;
    }

    private FrameworkElement BuildInfoSection(string glyph, string label, string body)
    {
        var sp = new StackPanel { Spacing = 10 };
        var header = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 8 };
        header.Children.Add(new FontIcon { Glyph = glyph, FontSize = 16, Foreground = Fg });
        header.Children.Add(new TextBlock { Text = label, FontSize = 18, FontWeight = Microsoft.UI.Text.FontWeights.SemiBold, Foreground = Fg });
        sp.Children.Add(header);
        sp.Children.Add(new TextBlock { Text = body, FontSize = 18, LineHeight = 26, Foreground = Fg, TextWrapping = TextWrapping.Wrap });
        return sp;
    }

    private FrameworkElement BuildTrial(bool showFeedback, bool correct)
    {
        var root = new Grid();
        root.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
        root.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
        root.RowDefinitions.Add(new RowDefinition { Height = new GridLength(1, GridUnitType.Star) });
        root.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
        root.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
        root.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
        root.Margin = new Thickness(0, 20, 0, 24);

        // Header
        var header = new Grid { Margin = new Thickness(60, 0, 60, 0) };
        header.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
        header.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
        var trialText = new TextBlock { Text = $"Trial {_state.CurrentTrial} of {_state.TotalTrials}", FontSize = 18, FontWeight = Microsoft.UI.Text.FontWeights.Medium, Foreground = TrialFg };
        var scoreText = new TextBlock { Text = $"Score: {_state.Score}/{_state.CurrentTrial}", FontSize = 18, FontWeight = Microsoft.UI.Text.FontWeights.Medium, Foreground = TrialFg };
        Grid.SetColumn(scoreText, 1);
        header.Children.Add(trialText);
        header.Children.Add(scoreText);
        Grid.SetRow(header, 0);
        root.Children.Add(header);

        // Progress dots
        var dots = BuildProgressDots();
        Grid.SetRow(dots, 1);
        root.Children.Add(dots);

        // Stimulus
        var stimulusContainer = new Grid { HorizontalAlignment = HorizontalAlignment.Center, VerticalAlignment = VerticalAlignment.Center };
        var stim = BuildStimulus();
        if (showFeedback) stim.Opacity = 0.4;
        stimulusContainer.Children.Add(stim);
        if (showFeedback)
        {
            var fi = new FontIcon
            {
                Glyph = correct ? "" : "",
                FontSize = 96,
                Foreground = new SolidColorBrush(correct ? Color.FromArgb(255, 80, 200, 120) : Color.FromArgb(255, 230, 80, 80)),
                HorizontalAlignment = HorizontalAlignment.Center,
                VerticalAlignment = VerticalAlignment.Center
            };
            stimulusContainer.Children.Add(fi);
        }
        Grid.SetRow(stimulusContainer, 2);
        root.Children.Add(stimulusContainer);

        // Hint
        var hint = new TextBlock { Text = _state.ExerciseType.HowToPlay(), FontSize = 18, Foreground = TrialFg, HorizontalAlignment = HorizontalAlignment.Center, Margin = new Thickness(0, 16, 0, 0) };
        Grid.SetRow(hint, 3);
        root.Children.Add(hint);

        // Response buttons (only when not in feedback), also bound to ← / →.
        if (!showFeedback)
        {
            var buttonStack = new StackPanel { Spacing = 10, HorizontalAlignment = HorizontalAlignment.Center };
            buttonStack.Children.Add(BuildResponseButtons());
            buttonStack.Children.Add(new TextBlock
            {
                Text = "or press ← / →",
                FontSize = 11,
                Foreground = new SolidColorBrush(Color.FromArgb((byte)(0.7 * 255), 31, 31, 31)),
                HorizontalAlignment = HorizontalAlignment.Center
            });
            Grid.SetRow(buttonStack, 4);
            root.Children.Add(buttonStack);
        }
        else
        {
            var spacer = new Border { Height = 48 };
            Grid.SetRow(spacer, 4);
            root.Children.Add(spacer);
        }

        return root;
    }

    private FrameworkElement BuildProgressDots()
    {
        var sp = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 4, HorizontalAlignment = HorizontalAlignment.Center, Margin = new Thickness(60, 8, 60, 0) };
        var total = _state.TotalTrials;
        var results = _state.Staircase.TrialResults;
        var max = Math.Min(total, 30);
        // Prominent dots on the mid-gray field: black for pending, green/red for done.
        var dotSize = total > 25 ? 5 : 7;
        for (var i = 0; i < max; i++)
        {
            SolidColorBrush fill;
            if (i < results.Count)
            {
                fill = results[i].Correct
                    ? new SolidColorBrush(Color.FromArgb(255, 80, 200, 120))
                    : new SolidColorBrush(Color.FromArgb(255, 230, 80, 80));
            }
            else
            {
                fill = new SolidColorBrush(Colors.Black);
            }
            sp.Children.Add(new Ellipse { Width = dotSize, Height = dotSize, Fill = fill });
        }
        if (total > 30)
            sp.Children.Add(new TextBlock { Text = $"+{total - 30}", FontSize = 9, Foreground = TrialFg, VerticalAlignment = VerticalAlignment.Center, Margin = new Thickness(4, 0, 0, 0) });
        return sp;
    }

    private FrameworkElement BuildStimulus()
    {
        return _state.ExerciseType switch
        {
            ExerciseType.ContrastDetection => BuildContrastDetectionStim(),
            ExerciseType.OrientationDiscrimination => BuildOrientationStim(),
            ExerciseType.FlankerMasking => BuildFlankerStim(),
            _ => new Grid()
        };
    }

    private FrameworkElement BuildContrastDetectionStim()
    {
        var size = _config.PatchPointSize;
        var sp = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 100, HorizontalAlignment = HorizontalAlignment.Center };
        sp.Children.Add(PatchCircle(_state.TargetPosition == 0, size));
        sp.Children.Add(PatchCircle(_state.TargetPosition == 1, size));
        return sp;
    }

    private FrameworkElement PatchCircle(bool hasGabor, double pointSize)
    {
        var pixelSize = _config.PatchPixelSize;
        var rng = new Random();
        var bmp = hasGabor
            ? GaborRenderer.Render(
                pixelSize,
                _state.Staircase.CurrentContrast,
                _config.SpatialFrequencyCpp,
                rng.NextDouble() * Math.PI,
                rng.NextDouble() * 2 * Math.PI,
                _config.SigmaPixels)
            : GaborRenderer.PlainGray(pixelSize);

        return BuildClippedPatch(bmp, pointSize);
    }

    private FrameworkElement BuildOrientationStim()
    {
        var size = _config.PatchPointSize;
        var bmp = GaborRenderer.Render(
            _config.PatchPixelSize,
            _state.Staircase.CurrentContrast,
            _config.SpatialFrequencyCpp,
            _state.TargetOrientation,
            0,
            _config.SigmaPixels);
        return BuildClippedPatch(bmp, size);
    }

    private FrameworkElement BuildFlankerStim()
    {
        const double FlankerContrast = 0.8;
        var size = _config.PatchPointSize;
        var gaps = _config.FlankerGapPoints;
        var gap = _state.FlankerDistanceLevel >= 0 && _state.FlankerDistanceLevel < gaps.Length
            ? gaps[_state.FlankerDistanceLevel]
            : gaps[1];

        var flankerBmp = GaborRenderer.Render(
            _config.PatchPixelSize, FlankerContrast, _config.SpatialFrequencyCpp,
            0, 0, _config.SigmaPixels);
        var centerBmp = GaborRenderer.Render(
            _config.PatchPixelSize, _state.Staircase.CurrentContrast, _config.SpatialFrequencyCpp,
            _state.TargetOrientation, 0, _config.SigmaPixels);

        var sp = new StackPanel { Orientation = Orientation.Horizontal, Spacing = gap, HorizontalAlignment = HorizontalAlignment.Center };
        sp.Children.Add(BuildClippedPatch(flankerBmp, size));
        sp.Children.Add(BuildClippedPatch(centerBmp, size));
        sp.Children.Add(BuildClippedPatch(flankerBmp, size));
        return sp;
    }

    private FrameworkElement BuildClippedPatch(WriteableBitmap bmp, double pointSize)
    {
        // Circle-clip via Border + CornerRadius (UIElement.Clip can only be Rectangle).
        // No aperture ring: on the mid-gray field the patch's Gaussian-tapered
        // edges fade into the surround, so an outline would draw a visible disc.
        var img = new Microsoft.UI.Xaml.Controls.Image
        {
            Source = bmp,
            Width = pointSize, Height = pointSize,
            Stretch = Stretch.UniformToFill
        };
        return new Border
        {
            Width = pointSize, Height = pointSize,
            CornerRadius = new CornerRadius(pointSize / 2),
            Child = img
        };
    }

    private FrameworkElement BuildResponseButtons()
    {
        var row = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 28, HorizontalAlignment = HorizontalAlignment.Center, Margin = new Thickness(0, 12, 0, 0) };
        if (_state.ExerciseType == ExerciseType.ContrastDetection)
        {
            row.Children.Add(ResponseButton("Left", "", () => _state.SubmitResponse(0)));
            row.Children.Add(ResponseButton("Right", "", () => _state.SubmitResponse(1)));
        }
        else
        {
            row.Children.Add(ResponseButton("Tilted Left", "", () => _state.SubmitResponse(0)));
            row.Children.Add(ResponseButton("Tilted Right", "", () => _state.SubmitResponse(1)));
        }
        return row;
    }

    private FrameworkElement BuildComplete()
    {
        var root = new StackPanel { Spacing = 28, HorizontalAlignment = HorizontalAlignment.Center, VerticalAlignment = VerticalAlignment.Center, Padding = new Thickness(40) };

        root.Children.Add(new FontIcon { Glyph = "", FontSize = 52, Foreground = Accent });
        root.Children.Add(new TextBlock { Text = "Session Complete", FontSize = 28, FontWeight = Microsoft.UI.Text.FontWeights.Bold, Foreground = Fg, HorizontalAlignment = HorizontalAlignment.Center });

        var stats = new StackPanel { Spacing = 14 };
        stats.Children.Add(BuildStatRow("Exercise", _state.ExerciseType.DisplayName()));
        stats.Children.Add(BuildStatRow("Accuracy", $"{_state.AccuracyPercent}%"));
        stats.Children.Add(BuildStatRow("Score", $"{_state.Score}/{_state.TotalTrials}"));
        stats.Children.Add(BuildStatRow("Contrast Threshold", _state.ThresholdDisplay));

        root.Children.Add(new Border
        {
            Background = FgSoft(26),
            CornerRadius = new CornerRadius(14),
            Padding = new Thickness(24),
            MinWidth = 340,
            Child = stats
        });

        var btns = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 16, HorizontalAlignment = HorizontalAlignment.Center };
        btns.Children.Add(SecondaryButton("Try Again", 120, () => _state.Phase = ExercisePhase.Ready));
        btns.Children.Add(AccentButton("Done", 120, () => Close()));
        root.Children.Add(btns);
        return root;
    }

    private FrameworkElement BuildStatRow(string label, string value)
    {
        var g = new Grid();
        g.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
        g.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
        var l = new TextBlock { Text = label, FontSize = 13, Foreground = Fg };
        var v = new TextBlock { Text = value, FontSize = 13, FontWeight = Microsoft.UI.Text.FontWeights.SemiBold, Foreground = Fg };
        Grid.SetColumn(v, 1);
        g.Children.Add(l);
        g.Children.Add(v);
        return g;
    }

    // ── Button helpers ──

    private Button AccentButton(string label, double width, Action onClick)
    {
        var btn = new Button
        {
            Content = new TextBlock { Text = label, FontSize = 15, FontWeight = Microsoft.UI.Text.FontWeights.SemiBold, Foreground = new SolidColorBrush(Colors.White) },
            Width = width, Height = 44,
            Background = Accent,
            BorderThickness = new Thickness(0),
            CornerRadius = new CornerRadius(10),
            HorizontalAlignment = HorizontalAlignment.Center
        };
        btn.Click += (_, _) => onClick();
        return btn;
    }

    private Button ResponseButton(string label, string glyph, Action onClick)
    {
        // Response buttons only appear on the mid-gray trial field, so dark
        // foreground + dark-tinted fill/border to read against the gray.
        var darkFg = TrialFg;
        var darkSoft = (byte alpha) => new SolidColorBrush(Color.FromArgb(alpha, 0, 0, 0));
        var inner = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 10, HorizontalAlignment = HorizontalAlignment.Center, VerticalAlignment = VerticalAlignment.Center };
        inner.Children.Add(new FontIcon { Glyph = glyph, FontSize = 18, Foreground = darkFg });
        inner.Children.Add(new TextBlock { Text = label, FontSize = 18, FontWeight = Microsoft.UI.Text.FontWeights.Medium, Foreground = darkFg });

        var btn = new Button
        {
            Content = inner, Width = 220, Height = 52,
            Background = darkSoft(26),
            BorderBrush = darkSoft(46),
            BorderThickness = new Thickness(1),
            CornerRadius = new CornerRadius(10)
        };
        btn.Click += (_, _) => onClick();
        return btn;
    }

    private Button SecondaryButton(string label, double width, Action onClick)
    {
        var btn = new Button
        {
            Content = new TextBlock { Text = label, FontSize = 14, FontWeight = Microsoft.UI.Text.FontWeights.Medium, Foreground = Fg },
            Width = width, Height = 40,
            Background = FgSoft(31),
            BorderThickness = new Thickness(0),
            CornerRadius = new CornerRadius(8)
        };
        btn.Click += (_, _) => onClick();
        return btn;
    }
}
