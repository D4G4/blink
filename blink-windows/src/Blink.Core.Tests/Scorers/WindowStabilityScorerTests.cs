using Blink.Core.FlowDetection.SignalProcessors;

namespace Blink.Core.Tests.Scorers;

public class WindowStabilityScorerTests
{
    private readonly WindowStabilityScorer _scorer = new();

    [Fact] public void NoChanges_MaxScore() =>
        Assert.Equal(1.0, _scorer.Score([], 1000));

    [Fact] public void TenPlusChanges_ZeroScore()
    {
        var ts = Enumerable.Range(0, 12).Select(i => 800.0 + i * 20).ToList();
        Assert.Equal(0.0, _scorer.Score(ts, 1000));
    }

    [Fact] public void FiveChanges_MidScore()
    {
        var ts = Enumerable.Range(0, 5).Select(i => 800.0 + i * 30).ToList();
        Assert.Equal(0.5, _scorer.Score(ts, 1000));
    }

    [Fact] public void OldChangesIgnored()
    {
        var ts = Enumerable.Range(0, 10).Select(i => 300.0 + i * 10).ToList();
        Assert.Equal(1.0, _scorer.Score(ts, 1000));
    }
}
