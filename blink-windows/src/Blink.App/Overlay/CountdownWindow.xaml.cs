using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Input;
using Microsoft.UI.Xaml.Media;
using Blink.App.Theme;

namespace Blink.App.Overlay;

public sealed partial class CountdownWindow : Window
{
    private readonly Action _onDone;
    private readonly Action _onSkip;
    private readonly DispatcherTimer _timer;
    private int _remaining = 3;

    public CountdownWindow(Action onDone, Action onSkip)
    {
        _onDone = onDone;
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

        // Apply theme gradient and text colors (respect "use dark overlay" setting)
        var theme = ThemeManager.Instance.UseDarkOverlay
            ? BlinkTheme.Dark
            : ThemeManager.Instance.Current;
        var isDark = Application.Current.RequestedTheme == ApplicationTheme.Dark;

        GradientTop.Color = theme.BackgroundTop(isDark);
        GradientBottom.Color = theme.BackgroundBottom(isDark);

        var fg = theme.OnBackgroundText(isDark);
        var textColor = new SolidColorBrush(fg);
        TitleText.Foreground = textColor;
        CountdownText.Foreground = new SolidColorBrush(theme.Accent(isDark));
        HintText.Foreground = textColor;

        // Ensure the Grid can receive keyboard focus
        RootGrid.IsTabStop = true;
        RootGrid.Focus(FocusState.Programmatic);

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
            _onDone();
        }
        else
        {
            CountdownText.Text = _remaining.ToString();
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
    }
}
