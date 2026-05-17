using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Media;
using Blink.App.Theme;

namespace Blink.App.Overlay;

public sealed partial class ToastWindow : Window
{
    private readonly Action _onDone;
    private readonly DispatcherTimer _timer;
    private int _remaining = 3;

    public ToastWindow(Action onDone)
    {
        _onDone = onDone;
        InitializeComponent();

        ExtendsContentIntoTitleBar = true;

        // Configure window: borderless, topmost, non-resizable
        var hWnd = WinRT.Interop.WindowNative.GetWindowHandle(this);
        var windowId = Microsoft.UI.Win32Interop.GetWindowIdFromWindow(hWnd);
        var appWindow = Microsoft.UI.Windowing.AppWindow.GetFromWindowId(windowId);

        var presenter = Microsoft.UI.Windowing.OverlappedPresenter.CreateForToolWindow();
        presenter.IsAlwaysOnTop = true;
        presenter.IsResizable = false;
        presenter.SetBorderAndTitleBar(false, false);
        appWindow.SetPresenter(presenter);

        appWindow.Resize(new Windows.Graphics.SizeInt32(280, 72));

        var workArea = Microsoft.UI.Windowing.DisplayArea.Primary.WorkArea;
        appWindow.Move(new Windows.Graphics.PointInt32(
            workArea.Width - 280 - 16,
            workArea.Height - 72 - 16));

        // Apply theme colors (swap to Dark theme when "use dark overlay" is on)
        var theme = ThemeManager.Instance.UseDarkOverlay
            ? BlinkTheme.Dark
            : ThemeManager.Instance.Current;
        var isDark = Application.Current.RequestedTheme == ApplicationTheme.Dark;
        var bgColor = theme.OverlayBackground(isDark);
        var textColor = theme.OverlayText(isDark);
        var accent = theme.Accent(isDark);

        RootGrid.Background = new SolidColorBrush(bgColor);
        MessageText.Foreground = new SolidColorBrush(textColor);
        IconElement.Foreground = new SolidColorBrush(textColor);
        CountdownRing.Foreground = new SolidColorBrush(accent);

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
            MessageText.Text = $"Break in {_remaining}s";
        }
    }
}
