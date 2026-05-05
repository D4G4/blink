namespace Blink.Core.FlowDetection.SignalProcessors;

public sealed class KeystrokeRhythmScorer
{
    private const double WindowSeconds = 120; // 2 minutes

    public double Score(List<double> keystrokeTimestamps, double now)
    {
        var windowStart = now - WindowSeconds;
        var recent = keystrokeTimestamps.Where(t => t > windowStart).OrderBy(t => t).ToList();

        if (recent.Count < 5) return 0.0;

        // Keys per minute
        var kpm = recent.Count / (WindowSeconds / 60.0);
        var kpmScore = Math.Min(kpm / 80.0, 1.0);

        // Inter-keystroke interval variance
        var intervals = new List<double>();
        for (int i = 1; i < recent.Count; i++)
            intervals.Add(recent[i] - recent[i - 1]);

        // Filter out think-pauses (>5s)
        var typingIntervals = intervals.Where(iv => iv <= 5.0).ToList();
        if (typingIntervals.Count < 3) return kpmScore * 0.5;

        var mean = typingIntervals.Average();
        var variance = typingIntervals.Average(iv => (iv - mean) * (iv - mean));
        var cv = mean > 0 ? Math.Sqrt(variance) / mean : 1.0;

        // Low CV = rhythmic. CV > 2.0 = sporadic
        var rhythmScore = Math.Max(0, Math.Min(1.0, 1.0 - (cv - 0.3) / 1.7));

        return kpmScore * 0.6 + rhythmScore * 0.4;
    }
}
