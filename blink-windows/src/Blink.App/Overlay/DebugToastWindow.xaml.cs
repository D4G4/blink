using Microsoft.UI.Xaml;

namespace Blink.App.Overlay;

public sealed partial class DebugToastWindow : Window
{
    private readonly DispatcherTimer _timer;

    public DebugToastWindow(string message)
    {
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

        // Positioned top-right (different from break toasts)
        appWindow.Resize(new Windows.Graphics.SizeInt32(320, 44));

        var workArea = Microsoft.UI.Windowing.DisplayArea.Primary.WorkArea;
        appWindow.Move(new Windows.Graphics.PointInt32(
            workArea.Width - 320 - 16,
            workArea.Y + 16));

        MessageText.Text = message;

        // Auto-dismiss after 4 seconds
        _timer = new DispatcherTimer { Interval = TimeSpan.FromSeconds(4) };
        _timer.Tick += (_, _) =>
        {
            _timer.Stop();
            Close();
        };
        _timer.Start();
    }
}
