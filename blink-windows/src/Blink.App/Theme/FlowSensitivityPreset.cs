namespace Blink.App.Theme;

/// Single source of truth for the three flow-sensitivity presets, mirroring
/// macOS FlowSensitivityView.Preset. The engine maps threshold = 1.1 -
/// sensitivity, so a higher sensitivity extends breaks more readily.
/// Balanced is the canonical default a fresh user gets.
public static class FlowSensitivityPreset
{
    public const string EyeHealthId = "eyeHealth";
    public const string BalancedId = "balanced";
    public const string DeepWorkId = "deepWork";

    public const double EyeHealth = 0.30;
    public const double Balanced = 0.50;
    public const double DeepWork = 0.75;

    /// The value a fresh user gets before onboarding writes a preset.
    public const double Default = Balanced;

    public static double ValueFor(string id) => id switch
    {
        EyeHealthId => EyeHealth,
        BalancedId => Balanced,
        DeepWorkId => DeepWork,
        _ => Default
    };

    /// Nearest preset by absolute distance (matches macOS Preset.closest(to:)).
    /// Midpoints: 0.40 between EyeHealth/Balanced, 0.625 between Balanced/DeepWork.
    public static string Closest(double sensitivity)
    {
        if (sensitivity < (EyeHealth + Balanced) / 2) return EyeHealthId;
        if (sensitivity < (Balanced + DeepWork) / 2) return BalancedId;
        return DeepWorkId;
    }

    public static string Description(string id) => id switch
    {
        EyeHealthId => "Blink prioritizes your eye health.\nBreaks come at 20 min unless your work rhythm is very intense.",
        BalancedId => "Blink learns your work rhythm and extends when you're truly focused.\nRecommended for most users.",
        DeepWorkId => "Fewer interruptions during focus. Blink reminds you gently.\nBest if you're disciplined about breaks.",
        _ => ""
    };
}
