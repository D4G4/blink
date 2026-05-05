using Microsoft.UI.Xaml;

namespace Blink.App.Settings;

public sealed partial class SettingsWindow : Window
{
    private readonly AppState _appState;

    public SettingsWindow(AppState appState)
    {
        _appState = appState;
        InitializeComponent();

        AppWindow.Resize(new Windows.Graphics.SizeInt32(440, 380));

        // TODO: Populate settings controls with current values
        // TODO: Wire up theme picker, sliders, toggles
    }
}
