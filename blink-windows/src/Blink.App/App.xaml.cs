using Microsoft.UI.Xaml;
using Blink.App.TrayIcon;
using Blink.App.Theme;

namespace Blink.App;

/// <summary>
/// Blink — tray-only app. No main window.
/// </summary>
public partial class App : Application
{
    private AppState? _appState;
    private TrayIconManager? _trayIcon;

    public App()
    {
        InitializeComponent();
    }

    protected override void OnLaunched(LaunchActivatedEventArgs args)
    {
        var themeManager = ThemeManager.Instance;
        _appState = new AppState();

        // Show onboarding on first launch
        if (!themeManager.HasCompletedOnboarding)
        {
            var onboarding = new Onboarding.OnboardingWindow(themeManager);
            onboarding.Activate();
            onboarding.Closed += (_, _) =>
            {
                themeManager.HasCompletedOnboarding = true;
                StartApp();
            };
        }
        else
        {
            StartApp();
        }
    }

    private void StartApp()
    {
        _appState!.Start();
        _trayIcon = new TrayIconManager(_appState);
        _trayIcon.Show();
    }
}
