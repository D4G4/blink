namespace Blink.Core.Timer;

public sealed class AdaptiveTimingEngine
{
    private readonly List<double> _acceptedIntervals = [];
    private const int MaxHistory = 50;
    private const double MinInterval = 900;   // 15 minutes
    private const double MaxInterval = 2700;  // 45 minutes

    public void RecordAcceptedBreak(double intervalSinceLastBreak)
    {
        _acceptedIntervals.Add(intervalSinceLastBreak);
        if (_acceptedIntervals.Count > MaxHistory)
            _acceptedIntervals.RemoveAt(0);
    }

    public double? SuggestedDuration()
    {
        if (_acceptedIntervals.Count < 10) return null;

        var sorted = _acceptedIntervals.OrderBy(x => x).ToList();
        var median = sorted[sorted.Count / 2];

        return Math.Min(MaxInterval, Math.Max(MinInterval, median));
    }

    public void Load(double[] intervals)
    {
        _acceptedIntervals.Clear();
        _acceptedIntervals.AddRange(intervals.TakeLast(MaxHistory));
    }

    public double[] SavedIntervals() => [.. _acceptedIntervals];
}
