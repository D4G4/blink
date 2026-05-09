using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Input;
using Microsoft.UI.Xaml.Media;
using Blink.App.Theme;

namespace Blink.App.Overlay;

public sealed partial class BreakTimerWindow : Window
{
    private readonly Action _onComplete;
    private readonly Action _onSkip;
    private readonly DispatcherTimer _timer;
    private readonly DispatcherTimer? _feedbackTimer;
    private int _remaining = 20;
    private int _total = 20;

    public BreakTimerWindow(Action onComplete, Action onSkip)
    {
        _onComplete = onComplete;
        _onSkip = onSkip;
        InitializeComponent();

        ExtendsContentIntoTitleBar = true;

        // Configure window: fullscreen, borderless, topmost
        var hWnd = WinRT.Interop.WindowNative.GetWindowHandle(this);
        var windowId = Microsoft.UI.Win32Interop.GetWindowIdFromWindow(hWnd);
        var appWindow = Microsoft.UI.Windowing.AppWindow.GetFromWindowId(windowId);

        var presenter = Microsoft.UI.Windowing.OverlappedPresenter.CreateForToolWindow();
        presenter.IsAlwaysOnTop = true;
        presenter.IsResizable = false;
        presenter.SetBorderAndTitleBar(false, false);
        appWindow.SetPresenter(presenter);

        // Use full display area (not workArea, which excludes taskbar)
        var display = Microsoft.UI.Windowing.DisplayArea.Primary;
        appWindow.Move(new Windows.Graphics.PointInt32(0, 0));
        appWindow.Resize(new Windows.Graphics.SizeInt32(display.OuterBounds.Width, display.OuterBounds.Height));

        // Apply theme gradient and text colors
        var theme = ThemeManager.Instance.Current;
        var isDark = Application.Current.RequestedTheme == ApplicationTheme.Dark;

        GradientTop.Color = theme.BackgroundTop(isDark);
        GradientBottom.Color = theme.BackgroundBottom(isDark);

        var textColor = new SolidColorBrush(theme.OnBackgroundText(isDark));
        TitleText.Foreground = textColor;
        TimerText.Foreground = textColor;
        BadgeText.Foreground = textColor;
        HintSkip.Foreground = textColor;
        HintExtend.Foreground = textColor;

        // Ensure the Grid can receive keyboard focus
        RootGrid.IsTabStop = true;
        RootGrid.Focus(FocusState.Programmatic);

        // Update progress ring initial state
        ProgressIndicator.Value = 100;

        // Start countdown
        _timer = new DispatcherTimer { Interval = TimeSpan.FromSeconds(1) };
        _timer.Tick += OnTick;
        _timer.Start();
    }

    private void OnTick(object? sender, object e)
    {
        _remaining--;
        if (_remaining <= 0)
        {
            _timer.Stop();
            _onComplete();
        }
        else
        {
            TimerText.Text = _remaining.ToString();
            ProgressIndicator.Value = (double)_remaining / _total * 100;
        }
    }

    private void OnKeyDown(object sender, KeyRoutedEventArgs e)
    {
        if (e.Key == Windows.System.VirtualKey.Escape)
        {
            _timer.Stop();
            _onSkip();
            e.Handled = true;
        }
        else if (e.Key == Windows.System.VirtualKey.Right)
        {
            _remaining += 20;
            _total += 20;
            TimerText.Text = _remaining.ToString();
            ProgressIndicator.Value = (double)_remaining / _total * 100;
            ShowExtendFeedback();
            e.Handled = true;
        }
    }

    private void ShowExtendFeedback()
    {
        ExtendFeedback.Opacity = 1;

        var fadeTimer = new DispatcherTimer { Interval = TimeSpan.FromSeconds(1) };
        fadeTimer.Tick += (_, _) =>
        {
            fadeTimer.Stop();
            ExtendFeedback.Opacity = 0;
        };
        fadeTimer.Start();
    }
}
