namespace Blink.Core.FlowDetection.SignalProcessors;

public sealed class WindowStabilityScorer
{
    private const double WindowSeconds = 300; // 5 minutes

    public double Score(List<double> titleChangeTimestamps, double now)
    {
        var windowStart = now - WindowSeconds;
        var recentChanges = titleChangeTimestamps.Count(t => t > windowStart);

        // 0 changes = 1.0, linear decrease, 10+ = 0.0
        return Math.Max(0.0, 1.0 - recentChanges / 10.0);
    }
}
