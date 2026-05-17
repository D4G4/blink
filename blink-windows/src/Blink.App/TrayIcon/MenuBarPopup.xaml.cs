using System.ComponentModel;
using Microsoft.UI.Dispatching;
using Microsoft.UI.Windowing;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Media;
using Microsoft.UI.Xaml.Media.Imaging;
using Windows.Graphics;
using Windows.UI;
using Microsoft.UI;
using Blink.App.Theme;
using Blink.Core.FlowDetection;

namespace Blink.App.TrayIcon;

public sealed partial class MenuBarPopup : Window
{
    private readonly AppState _appState;
    private readonly DispatcherQueue _dispatcher;
    private const int PopupWidth = 320;

    public event Action? OnSettingsRequested;
    public event Action? OnTakeBreakNowRequested;
    public event Action? OnQuitRequested;
    public event Action? OnAboutRequested;

    public MenuBarPopup(AppState appState)
    {
        _appState = appState;
        _dispatcher = DispatcherQueue.GetForCurrentThread();
        InitializeComponent();
        AppWindow.SetIcon(Path.Combine(AppContext.BaseDirectory, "app.ico"));

        if (AppWindow.Presenter is OverlappedPresenter op)
        {
            op.IsResizable = false;
            op.IsMaximizable = false;
            op.IsMinimizable = false;
            op.SetBorderAndTitleBar(true, false);
        }

        ApplyTheme();
        Refresh();

        _appState.PropertyChanged += OnAppStatePropertyChanged;
        UpdateChecker.Instance.PropertyChanged += OnUpdateCheckerChanged;
        Activated += OnActivated;
        Closed += (_, _) =>
        {
            _appState.PropertyChanged -= OnAppStatePropertyChanged;
            UpdateChecker.Instance.PropertyChanged -= OnUpdateCheckerChanged;
        };
    }

    public void ShowNearTray()
    {
        var area = DisplayArea.Primary;
        var height = MeasureContentHeight();
        var x = area.WorkArea.X + area.WorkArea.Width - PopupWidth - 12;
        var y = area.WorkArea.Y + area.WorkArea.Height - height - 12;
        AppWindow.MoveAndResize(new RectInt32(x, y, PopupWidth, height));
        Refresh();
        Activate();

        // Win11 tray-overflow flyout only dismisses when a different window
        // becomes foreground. SetForegroundWindow has restrictions unless our
        // thread is attached to the foreground thread's input queue.
        var hwnd = WinRT.Interop.WindowNative.GetWindowHandle(this);
        var fore = Blink.Platform.Native.NativeMethods.GetForegroundWindow();
        var foreThread = Blink.Platform.Native.NativeMethods.GetWindowThreadProcessId(fore, out _);
        var thisThread = Blink.Platform.Native.NativeMethods.GetCurrentThreadId();
        var attached = false;
        if (foreThread != 0 && foreThread != thisThread)
            attached = Blink.Platform.Native.NativeMethods.AttachThreadInput(thisThread, foreThread, true);
        Blink.Platform.Native.NativeMethods.BringWindowToTop(hwnd);
        Blink.Platform.Native.NativeMethods.SetForegroundWindow(hwnd);
        Blink.Platform.Native.NativeMethods.SetFocus(hwnd);
        if (attached)
            Blink.Platform.Native.NativeMethods.AttachThreadInput(thisThread, foreThread, false);
    }

    private int MeasureContentHeight()
    {
        var hasUpdate = UpdateChecker.Instance.UpdateAvailable;
        return hasUpdate ? 500 : 400;
    }

    private void OnActivated(object sender, WindowActivatedEventArgs args)
    {
        if (args.WindowActivationState == WindowActivationState.Deactivated)
        {
            try { AppWindow.Hide(); } catch { }
        }
    }

    private void OnAppStatePropertyChanged(object? sender, PropertyChangedEventArgs e)
    {
        _dispatcher.TryEnqueue(Refresh);
    }

    private void OnUpdateCheckerChanged(object? sender, PropertyChangedEventArgs e)
    {
        _dispatcher.TryEnqueue(RefreshUpdateBanner);
    }

    private void ApplyTheme()
    {
        var theme = ThemeManager.Instance.Current;
        var isDark = Application.Current.RequestedTheme == ApplicationTheme.Dark;

        var top = theme.BackgroundTop(isDark);
        var bottom = theme.BackgroundBottom(isDark);
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

        var accent = theme.Accent(isDark);
        var accentBrush = new SolidColorBrush(accent);
        var accentSoft = new SolidColorBrush(Color.FromArgb(15, accent.R, accent.G, accent.B));
        var accentMid = new SolidColorBrush(Color.FromArgb(38, accent.R, accent.G, accent.B));

        var textOnAccent = new SolidColorBrush(theme.TextOnAccent(isDark));

        IconBackground.Background = new SolidColorBrush(top);
        TimerCard.Background = accentSoft;
        ProgressTrack.Fill = accentMid;
        ProgressFill.Fill = accentBrush;
        StatsIcon.Foreground = accentBrush;
        TakeBreakButton.Background = accentBrush;
        TakeBreakButton.Foreground = textOnAccent;

        UpdateBanner.Background = new SolidColorBrush(Color.FromArgb(20, accent.R, accent.G, accent.B));
        UpdateBannerIcon.Foreground = accentBrush;
        UpdateDownloadButton.Background = accentBrush;
        UpdateDownloadButton.Foreground = textOnAccent;

        var iconPath = Path.Combine(AppContext.BaseDirectory, "Assets", $"theme-{theme.Id}.png");
        if (File.Exists(iconPath))
            HeaderIcon.Source = new BitmapImage(new Uri(iconPath));
    }

    private void Refresh()
    {
        ApplyTheme();
        CountdownText.Text = FormatTime(_appState.RemainingSeconds);
        StateLabel.Text = StateLabelText();
        DurationLabel.Text = $"{(int)_appState.TimerTotal / 60} min";
        StatsText.Text = $"{_appState.BreaksTakenToday} breaks today";

        var totalDuration = _appState.TimerTotal;
        var progress = totalDuration > 0 ? 1.0 - (_appState.RemainingSeconds / totalDuration) : 0;
        progress = Math.Clamp(progress, 0, 1);
        ProgressFill.Width = (PopupWidth - 24 - 28) * progress;

        var (color, label) = FlowBadgeColorAndLabel();
        FlowStateDot.Fill = new SolidColorBrush(color);
        FlowStateBadge.Text = label;

        TakeBreakButton.IsEnabled = !_appState.IsBreakPrompted;

        RefreshUpdateBanner();
    }

    private void RefreshUpdateBanner()
    {
        var checker = UpdateChecker.Instance;
        if (checker.UpdateAvailable && !string.IsNullOrEmpty(checker.LatestVersion))
        {
            UpdateBannerText.Text = $"v{checker.LatestVersion} available";
            UpdateBanner.Visibility = Visibility.Visible;
            UpdateDownloadButton.Visibility = string.IsNullOrEmpty(checker.DownloadUrl)
                ? Visibility.Collapsed : Visibility.Visible;
        }
        else
        {
            UpdateBanner.Visibility = Visibility.Collapsed;
        }
    }

    private (Color, string) FlowBadgeColorAndLabel()
    {
        if (_appState.IsVideoPlaying) return (Colors.LimeGreen, "Video");
        return _appState.DisplayStateName switch
        {
            "Working" => (Colors.Gray, "Working"),
            "Away" => (Colors.Orange, "Away"),
            "Meeting" => (Colors.IndianRed, "Meeting"),
            "OnBreak" => (Accent(), "Break"),
            _ => (Colors.Gray, "Working")
        };
    }

    private Color Accent()
    {
        var isDark = Application.Current.RequestedTheme == ApplicationTheme.Dark;
        return ThemeManager.Instance.Current.Accent(isDark);
    }

    private string StateLabelText()
    {
        if (_appState.IsVideoPlaying) return "Video playing — timer paused";
        return _appState.DisplayStateName switch
        {
            "Working" => "Timer running",
            "Away" => "Away — timer paused",
            "Meeting" => "In meeting — timer paused",
            "OnBreak" => "Break time",
            _ => "Timer running"
        };
    }

    private static string FormatTime(double seconds)
    {
        var m = (int)seconds / 60;
        var s = (int)seconds % 60;
        return $"{m}:{s:D2}";
    }

    private void OnTakeBreakNow(object sender, RoutedEventArgs e)
    {
        AppWindow.Hide();
        OnTakeBreakNowRequested?.Invoke();
    }

    private void OnAbout(object sender, RoutedEventArgs e)
    {
        AppWindow.Hide();
        OnAboutRequested?.Invoke();
    }

    private void OnPreferences(object sender, RoutedEventArgs e)
    {
        AppWindow.Hide();
        OnSettingsRequested?.Invoke();
    }

    private void OnQuit(object sender, RoutedEventArgs e)
    {
        OnQuitRequested?.Invoke();
    }

    private void OnDownloadUpdate(object sender, RoutedEventArgs e)
    {
        var url = UpdateChecker.Instance.DownloadUrl;
        if (string.IsNullOrEmpty(url)) return;
        System.Diagnostics.Process.Start(new System.Diagnostics.ProcessStartInfo
        {
            FileName = url,
            UseShellExecute = true
        });
    }
}
