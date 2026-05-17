namespace Blink.Core.FlowDetection;

/// <summary>
/// Configuration derived from the user's sensitivity setting (0.4–0.9).
/// </summary>
public sealed record FlowConfig(int MaxExtensions)
{
    public static FlowConfig ForSensitivity(double sensitivity)
    {
        var t = (sensitivity - 0.4) / (0.9 - 0.4);
        int extensions = t < 0.2 ? 0 : t < 0.7 ? 1 : 2;
        return new FlowConfig(extensions);
    }
}
