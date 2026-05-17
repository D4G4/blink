using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Media;
using Blink.App.Theme;

namespace Blink.App.Overlay;

public sealed partial class FlowNudgeToastWindow : Window
{
    private readonly Action _onTakeBreak;
    private readonly DispatcherTimer _timer;

    public FlowNudgeToastWindow(string message, Action onTakeBreak)
    {
        _onTakeBreak = onTakeBreak;
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

        appWindow.Resize(new Windows.Graphics.SizeInt32(320, 80));

        var workArea = Microsoft.UI.Windowing.DisplayArea.Primary.WorkArea;
        appWindow.Move(new Windows.Graphics.PointInt32(
            workArea.Width - 320 - 16,
            workArea.Height - 80 - 16));

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
        MessageText.Text = message;

        // Button: accent background + contrasting text
        BreakButton.Background = new SolidColorBrush(accent);
        BreakButton.Foreground = new SolidColorBrush(theme.TextOnAccent(isDark));

        // Auto-dismiss after 7 seconds
        _timer = new DispatcherTimer { Interval = TimeSpan.FromSeconds(7) };
        _timer.Tick += (_, _) =>
        {
            _timer.Stop();
            Close();
        };
        _timer.Start();
    }

    private void OnBreak(object sender, RoutedEventArgs e)
    {
        _timer.Stop();
        _onTakeBreak();
        Close();
    }
}
