using Microsoft.UI.Dispatching;
using Microsoft.UI.Xaml;
using Blink.App.TrayIcon;
using Blink.App.Theme;
using Blink.App.Logging;

namespace Blink.App;

/// <summary>
/// Blink — tray-only app. No main window.
/// </summary>
public partial class App : Application
{
    private AppState? _appState;
    private TrayIconManager? _trayIcon;
    private MenuBarPopup? _menuPopup;

    public App()
    {
        InitializeComponent();
        DispatcherShutdownMode = DispatcherShutdownMode.OnExplicitShutdown;
        AppDomain.CurrentDomain.UnhandledException += (_, e) =>
            Log.Error("Unhandled exception", e.ExceptionObject as Exception ?? new Exception(e.ExceptionObject?.ToString() ?? "?"));
    }

    protected override void OnLaunched(LaunchActivatedEventArgs args)
    {
        var version = typeof(App).Assembly.GetName().Version?.ToString(3) ?? "?";
        Log.Info($"OnLaunched (v{version})");
        var themeManager = ThemeManager.Instance;
        _appState = new AppState();

        if (!themeManager.HasCompletedOnboarding)
        {
            var onboarding = new Onboarding.OnboardingWindow(themeManager);
            onboarding.Activate();
            onboarding.Closed += (_, _) =>
            {
                themeManager.HasCompletedOnboarding = true;
                StartApp(showWelcomeBalloon: true);
            };
        }
        else
        {
            StartApp(showWelcomeBalloon: false);
        }
    }

    private void StartApp(bool showWelcomeBalloon)
    {
        UpdateChecker.Instance.StartPeriodicChecks();
        _appState!.Start(DispatcherQueue.GetForCurrentThread());

        _trayIcon = new TrayIconManager(_appState);
        _trayIcon.OnLeftClickRequested += ShowOrHideMenuPopup;
        _trayIcon.OnSettingsRequested += () =>
        {
            var settings = new Settings.SettingsWindow(_appState!);
            settings.Activate();
        };
        _trayIcon.OnTakeBreakNowRequested += () => _appState!.ShowBreakPrompt();
        _trayIcon.OnQuitRequested += () =>
        {
            _trayIcon?.Dispose();
            Current.Exit();
        };
        _trayIcon.Show();

        if (showWelcomeBalloon)
        {
            _trayIcon.ShowBalloon(
                "Blink is running",
                "Click the ^ in your taskbar to find Blink, then drag it onto the bar to pin it.");
        }
    }

    private void ShowOrHideMenuPopup()
    {
        if (_menuPopup == null)
        {
            _menuPopup = new MenuBarPopup(_appState!);
            _menuPopup.OnSettingsRequested += () =>
            {
                var settings = new Settings.SettingsWindow(_appState!);
                settings.Activate();
            };
            _menuPopup.OnTakeBreakNowRequested += () => _appState!.ShowBreakPrompt();
            _menuPopup.OnAboutRequested += () =>
            {
                var win = new Onboarding.WhyExistWindow(ThemeManager.Instance.Current);
                win.Activate();
            };
            _menuPopup.OnEyeExerciseRequested += () =>
            {
                var win = new GaborExercise.GaborExerciseWindow(ThemeManager.Instance.Current);
                win.Activate();
            };
            _menuPopup.OnQuitRequested += () =>
            {
                _trayIcon?.Dispose();
                Current.Exit();
            };
        }
        _menuPopup.ShowNearTray();
    }
}
