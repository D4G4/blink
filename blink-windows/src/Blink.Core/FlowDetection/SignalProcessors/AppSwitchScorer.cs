namespace Blink.Core.FlowDetection.SignalProcessors;

public sealed class AppSwitchScorer
{
    private const double WindowSeconds = 300; // 5 minutes

    public double Score(List<double> switchTimestamps, double now)
    {
        var windowStart = now - WindowSeconds;
        var recentCount = switchTimestamps.Count(t => t > windowStart);

        return recentCount switch
        {
            0 => 1.0,
            1 => 0.85,
            2 => 0.7,
            3 => 0.5,
            4 => 0.3,
            _ => 0.0
        };
    }
}
